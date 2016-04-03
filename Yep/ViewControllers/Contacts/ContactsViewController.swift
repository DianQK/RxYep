//
//  ContactsViewController.swift
//  Yep
//
//  Created by NIX on 15/3/16.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import RealmSwift
import Ruler
import RxSwift
import RxCocoa
import RxDataSources
import RxOptional
import NSObject_Rx

private typealias ContactsSection = AnimatableSectionModel<ContactsViewController.Section, User>

class ContactsViewController: UIViewController, NavigationBarAutoShowable {

    @IBOutlet weak var contactsTableView: UITableView!

    @IBOutlet private weak var coverUnderStatusBarView: UIView! // 覆盖 Status Bar ？
    
    @IBOutlet weak var addFriendBarButton: UIBarButtonItem!

    #if DEBUG
    private lazy var contactsFPSLabel: FPSLabel = {
        let label = FPSLabel()
        return label
    }()
    #endif

    private var searchController: UISearchController?
    private var searchControllerIsActive: Bool {
        return searchController?.active ?? false
    }

    private var originalNavigationControllerDelegate: UINavigationControllerDelegate?
    private lazy var contactsSearchTransition = ContactsSearchTransition()
    
    private var viewModel: ContactsViewModel!

    private static let cellIdentifier = "ContactsCell"
    /// viewModel
    private lazy var friends = normalFriends()
    /// viewModel
    private var filteredFriends: Results<User>? // 数据持久化
    /// viewModel
    private var searchedUsers = [DiscoveredUser]()
    /// viewModel ?
    private var realmNotificationToken: NotificationToken?

    private lazy var noContactsFooterView: InfoView = InfoView(NSLocalizedString("No friends yet.\nTry discover or add some.", comment: ""))
    /// viewModel
    private var noContacts = false {
        didSet {
            if noContacts != oldValue {
                contactsTableView.tableFooterView = noContacts ? noContactsFooterView : UIView()
            }
        }
    }

    private struct Listener {
        static let Nickname = "ContactsViewController.Nickname"
        static let Avatar = "ContactsViewController.Avatar"
    }

    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)

        YepUserDefaults.avatarURLString.removeListenerWithName(Listener.Avatar)
        YepUserDefaults.nickname.removeListenerWithName(Listener.Nickname)

        contactsTableView?.delegate = nil

        realmNotificationToken?.stop()

        // ref http://stackoverflow.com/a/33281648
        if let superView = searchController?.view.superview {
            superView.removeFromSuperview()
        }

        println("deinit Contacts")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        yepAutoShowNavigationBar()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Contacts", comment: "")

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ContactsViewController.syncFriendships(_:)), name: FriendsInContactsViewController.Notification.NewFriends, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ContactsViewController.deactiveSearchController(_:)), name: YepConfig.Notification.switchedToOthersFromContactsTab, object: nil)

        coverUnderStatusBarView.hidden = true

        contactsTableView.separatorColor = UIColor.yepCellSeparatorColor()
        contactsTableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)

        contactsTableView.registerNib(UINib(nibName: ContactsViewController.cellIdentifier, bundle: nil), forCellReuseIdentifier: ContactsViewController.cellIdentifier)
        contactsTableView.rowHeight = 80
        contactsTableView.tableFooterView = UIView()

        noContacts = friends.isEmpty

        realmNotificationToken = friends.realm?.addNotificationBlock { [weak self] notification, realm in
            if let strongSelf = self {
                strongSelf.noContacts = strongSelf.friends.isEmpty
            }
            
            self?.updateContactsTableView()
        }

        YepUserDefaults.nickname.bindListener(Listener.Nickname) { [weak self] _ in // 两个绑定监听
            dispatch_async(dispatch_get_main_queue()) {
                self?.updateContactsTableView()
            }
        }

        YepUserDefaults.avatarURLString.bindListener(Listener.Avatar) { [weak self] _ in
            dispatch_async(dispatch_get_main_queue()) {
                self?.updateContactsTableView()
            }
        }

        #if DEBUG
            view.addSubview(contactsFPSLabel)
        #endif
        
        viewModel = ContactsViewModel()
        
        let dataSource = RxTableViewSectionedReloadDataSource<ContactsSection>()
        dataSource.configureCell = { ds, tb, ip, i in
            let cell = tb.dequeueReusableCellWithIdentifier(ContactsViewController.cellIdentifier) as! ContactsCell
            switch ds.sectionAtIndex(ip.section).model {
            case .Local:
                cell.configureWithUser(i.identity)
//                if searchControllerIsActive { // TODO: - 注意去判断这个
//                    cell.configureForSearchWithUser(friend)
//                } else {
//                    cell.configureWithUser(friend)
//                }
            case .Online:
                cell.configureForSearchWithUser(i.identity)
            }
            return cell
        }
//        dataSource.titleForHeaderInSection = { ds, section in // TODO: - 加一个搜索的判断，只有在搜索的时候才去显示 == searchControllerIsActive But? why?
//            switch ds.sectionAtIndex(section).identity {
//            case .Local:
//                return NSLocalizedString("Friends", comment: "")
//            case .Online:
//                return NSLocalizedString("Users", comment: "")
//            }
//        }
        
        viewModel.friends.asObservable()
            .map { $0.map { $0 } }
            .map { [ContactsSection(model: .Local, items: $0)] }
            .bindTo(contactsTableView.rx_itemsWithDataSource(dataSource))
            .addDisposableTo(rx_disposeBag)
        
        /// 超过一定人数才显示搜索框， 另一种设置是 friends.count > Ruler.iPhoneVertical(6, 8, 10, 12).value
        viewModel.friends.asObservable()
            .map { !$0.isEmpty }.subscribeNext { [unowned self] isNotEmpty in
                if isNotEmpty {
                    let searchController = UISearchController(searchResultsController: nil)
                    searchController.delegate = self
                
                    searchController.searchResultsUpdater = self
                    searchController.dimsBackgroundDuringPresentation = false
                
                    searchController.searchBar.backgroundColor = UIColor.whiteColor()
                    searchController.searchBar.barTintColor = UIColor.whiteColor()
                    searchController.searchBar.searchBarStyle = .Minimal
                    searchController.searchBar.placeholder = NSLocalizedString("Search Friend", comment: "")
                    searchController.searchBar.sizeToFit()
                
                    searchController.searchBar.delegate = self
                
                    self.contactsTableView.tableHeaderView = searchController.searchBar
                
                    self.searchController = searchController
                
                    // ref http://stackoverflow.com/questions/30937275/uisearchcontroller-doesnt-hide-view-when-pushed
                    //self.definesPresentationContext = true
                
                    //contactsTableView.contentOffset.y = CGRectGetHeight(searchController.searchBar.frame)
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        contactsTableView.rx_modelItemSelected(IdentifiableValue<User>)
            .subscribeNext { [unowned self] tb, i ,ip in
                switch ip.section {
                case Section.Local.rawValue:
                    self.searchController?.active = false
                    self.yep_performSegueWithIdentifier("showProfile", sender: Box(i.identity))
                case Section.Online.rawValue:
                    println("WARING")
//                    let discoveredUser = searchedUsers[indexPath.row] // Todo
//                    searchController?.active = false
//                    performSegueWithIdentifier("showProfile", sender: Box<DiscoveredUser>(discoveredUser))
                default: break
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        /// 点击跳转到添加朋友
        addFriendBarButton.rx_tap
            .subscribeNext { [unowned self] in
                self.performSegueWithIdentifier("showAddFriends", sender: nil)
            }
            .addDisposableTo(rx_disposeBag)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if let delegate = originalNavigationControllerDelegate {
            navigationController?.delegate = delegate
        }
    }

    // MARK: Actions

    @objc private func deactiveSearchController(sender: NSNotification) {
        if let searchController = searchController {
            searchController.active = false
        }
    }

    private func updateContactsTableView(scrollsToTop scrollsToTop: Bool = false) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            self?.contactsTableView.reloadData()

            if scrollsToTop {
                self?.contactsTableView.yep_scrollsToTop()
            }
        }
    }

    @objc private func syncFriendships(sender: NSNotification) {
        syncFriendshipsAndDoFurtherAction {
            dispatch_async(dispatch_get_main_queue()) {
                self.updateContactsTableView()
            }
        }
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        // TODO: - 处理
//        else if let discoveredUser = (sender as? Box<DiscoveredUser>)?.value {
//            vc.profileUser = .DiscoveredUserType(discoveredUser)
//        }

        if let userBox = sender as? Box<User> where segue.identifier == "showProfile" {
            let vc = segue.destinationViewController as! ProfileViewController
            if userBox.value.userID != YepUserDefaults.userID.value {
                vc.profileUser = .UserType(userBox.value)
            }
            vc.hidesBottomBarWhenPushed = true
            vc.setBackButtonWithTitle()
        
        } else if segue.identifier == "showSearchContacts" {
            let vc = segue.destinationViewController as! SearchContactsViewController
            vc.originalNavigationControllerDelegate = navigationController?.delegate
            
            vc.hidesBottomBarWhenPushed = true
            
            // 在自定义 push 之前，记录原始的 NavigationControllerDelegate 以便 pop 后恢复
            originalNavigationControllerDelegate = navigationController?.delegate
            
            navigationController?.delegate = contactsSearchTransition
            
            vc.viewModel = viewModel
        }
    }
}

// MARK: - UITableViewDelegate

extension ContactsViewController: UITableViewDelegate {

    enum Section: Int {
        case Local
        case Online
    }

    /// TODO: - 留意这个
    private func numberOfRowsInSection(section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }

        switch section {
        case .Local:
            return searchControllerIsActive ? (filteredFriends?.count ?? 0) : friends.count
        case .Online:
            return searchControllerIsActive ? searchedUsers.count : 0
        }
    }
    /// TODO: - 同样留意这个
    private func friendAtIndexPath(indexPath: NSIndexPath) -> User? {
        let index = indexPath.row
        let friend = searchControllerIsActive ? filteredFriends?[safe: index] : friends[safe: index]
        return friend
    }

    /// TODO: - 同样留意这个
    func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {

        guard let cell = cell as? ContactsCell else {
            return
        }

        cell.avatarImageView.image = nil
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        defer {
            tableView.deselectRowAtIndexPath(indexPath, animated: true)
        }

        guard let section = Section(rawValue: indexPath.section) else {
            return
        }

        switch section {

        case .Local:

            if let friend = friendAtIndexPath(indexPath) {
                searchController?.active = false
                performSegueWithIdentifier("showProfile", sender: friend)
            }

        case .Online:

            let discoveredUser = searchedUsers[indexPath.row]
            searchController?.active = false
            performSegueWithIdentifier("showProfile", sender: Box<DiscoveredUser>(discoveredUser))
        }
   }
}

// MARK: - UISearchResultsUpdating 

extension ContactsViewController: UISearchResultsUpdating {

    func updateSearchResultsForSearchController(searchController: UISearchController) {

        guard let searchText = searchController.searchBar.text else {
            return
        }
        
        let predicate = NSPredicate(format: "nickname CONTAINS[c] %@ OR username CONTAINS[c] %@", searchText, searchText)
        let filteredFriends = friends.filter(predicate)
        self.filteredFriends = filteredFriends

        updateContactsTableView(scrollsToTop: !filteredFriends.isEmpty)

        searchUsersByQ(searchText, failureHandler: nil, completion: { [weak self] users in

            //println("searchUsersByQ users: \(users)")
            
            dispatch_async(dispatch_get_main_queue()) {

                guard let filteredFriends = self?.filteredFriends else {
                    return
                }

                // 剔除 filteredFriends 里已有的

                var searchedUsers = [DiscoveredUser]()

                let filteredFriendUserIDSet = Set<String>(filteredFriends.map({ $0.userID }))

                for user in users {
                    if !filteredFriendUserIDSet.contains(user.id) {
                        searchedUsers.append(user)
                    }
                }

                self?.searchedUsers = searchedUsers

                self?.updateContactsTableView()
            }
        })
    }
}

// MARK: - UISearchBarDelegate

extension ContactsViewController: UISearchBarDelegate {

    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {

        performSegueWithIdentifier("showSearchContacts", sender: nil)

        return false
    }

    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {

        if let searchController = searchController {
            updateSearchResultsForSearchController(searchController)
        }
    }
}

extension ContactsViewController: UISearchControllerDelegate {

    func willPresentSearchController(searchController: UISearchController) {
        println("willPresentSearchController")
        coverUnderStatusBarView.hidden = false
    }

    func willDismissSearchController(searchController: UISearchController) {
        println("willDismissSearchController")
        coverUnderStatusBarView.hidden = true
    }
}

