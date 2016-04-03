//
//  SearchContactsViewController.swift
//  Yep
//
//  Created by NIX on 16/3/21.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import UIKit
import RealmSwift
import KeyboardMan
import RxSwift
import RxCocoa
import RxDataSources
import RxOptional
import NSObject_Rx

enum RxSection: Hashable {
    case Local(User)
    case Online(DiscoveredUser)
    
    var hashValue: Int {
        switch self {
        case .Local(let user):
            return user.hashValue
        case .Online(let user):
            return user.hashValue
        }
    }
}

func ==(lhs: RxSection, rhs: RxSection) -> Bool {
    return lhs == rhs
}

private typealias ContactsSection = AnimatableSectionModel<String, RxSection> // TODO: 事实上我们可以把 Section 这个 enum 放在 item

class SearchContactsViewController: SegueViewController {

    var originalNavigationControllerDelegate: UINavigationControllerDelegate?
    private var contactsSearchTransition: ContactsSearchTransition?

    @IBOutlet weak var searchBar: UISearchBar! {
        didSet {
            searchBar.placeholder = NSLocalizedString("Search Friend", comment: "")
        }
    }
    @IBOutlet weak var searchBarTopConstraint: NSLayoutConstraint!

    @IBOutlet weak var contactsTableView: UITableView! {
        didSet {
            contactsTableView.separatorColor = UIColor.yepCellSeparatorColor()
            contactsTableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)

            contactsTableView.registerClass(TableSectionTitleView.self, forHeaderFooterViewReuseIdentifier: SearchContactsViewController.headerIdentifier)
            contactsTableView.registerNib(UINib(nibName: SearchContactsViewController.cellIdentifier, bundle: nil), forCellReuseIdentifier: SearchContactsViewController.cellIdentifier)
            contactsTableView.rowHeight = 80
            contactsTableView.tableFooterView = UIView()
        }
    }

    private let keyboardMan = KeyboardMan()

    private var searchControllerIsActive = false

    private static let headerIdentifier = "TableSectionTitleView"
    private static let cellIdentifier = "SearchedContactsCell"
    /// 和 ContactsViewController 共用一个 ViewModel 用 "!"
    weak var viewModel: ContactsViewModel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Search Contacts"

        keyboardMan.animateWhenKeyboardAppear = { [weak self] _, keyboardHeight, _ in
            self?.contactsTableView.contentInset.bottom = keyboardHeight
            self?.contactsTableView.scrollIndicatorInsets.bottom = keyboardHeight
        }

        keyboardMan.animateWhenKeyboardDisappear = { [weak self] _ in
            self?.contactsTableView.contentInset.bottom = 0
            self?.contactsTableView.scrollIndicatorInsets.bottom = 0
        }
        
        searchBar.rx_text.asDriver()
            .debounce(0.3)
            .drive(viewModel.searchText)
            .addDisposableTo(self.rx_disposeBag)
        
        searchBar.rx_text.asDriver()
            .map { $0.isNotEmpty }
            .driveNext { [unowned self] in
                self.searchControllerIsActive = $0
            }
            .addDisposableTo(rx_disposeBag)
        
        let dataSource = RxTableViewSectionedReloadDataSource<ContactsSection>()
        dataSource.configureCell = { _, tb, ip, i in
            let cell = tb.dequeueReusableCellWithIdentifier(SearchContactsViewController.cellIdentifier) as! SearchedContactsCell
            switch i.identity {
            case .Local(let user):
                cell.configureWithUser(user)
            case .Online(let user):
                cell.configureWithDiscoveredUser(user)
            }
            return cell
        }
        
        Observable.combineLatest(viewModel.filteredFriends.asObservable().filterNil(), viewModel.searchedUsers.asObservable()) { filteredFriends, searchedUsers -> [ContactsSection] in // 过滤的最佳时机
            
            guard searchedUsers.isNotEmpty else {
                let filteredFriends = filteredFriends.map { RxSection.Local($0) }
                return [ContactsSection(model: NSLocalizedString("Friends", comment: ""), items: filteredFriends)]
            }
            
            let filterSearchedUsers = searchedUsers
                .filter { searchedUser in
                    return !filteredFriends.contains { $0.userID == searchedUser.id }
                }
                .map { RxSection.Online($0) }
            let filteredFriends = filteredFriends.map { RxSection.Local($0) }
            
            return [ContactsSection(model: NSLocalizedString("Friends", comment: ""), items: filteredFriends),
                ContactsSection(model: NSLocalizedString("Users", comment: ""), items: filterSearchedUsers)]
            }
            .bindTo(contactsTableView.rx_itemsWithDataSource(dataSource))
            .addDisposableTo(rx_disposeBag)
        
        contactsTableView.rx_modelItemSelected(IdentifiableValue<RxSection>)
            .subscribeNext { [unowned self] tb, i, ip in
                self.hideKeyboard()
                switch i.identity {
                case .Local(let user):
                    self.performSegueWithIdentifier("showProfile", sender: Box(user))
                case .Online(let user):
                    self.performSegueWithIdentifier("showProfile", sender: Box(user))
                }
                tb.deselectRowAtIndexPath(ip, animated: true)
            }
            .addDisposableTo(rx_disposeBag)
        
        contactsTableView.rx_setDelegate(self)
        
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setNavigationBarHidden(true, animated: true)

        //(tabBarController as? YepTabBarController)?.setTabBarHidden(true, animated: true)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        if let delegate = contactsSearchTransition {
            navigationController?.delegate = delegate
        }

        UIView.animateWithDuration(0.25, delay: 0.0, options: .CurveEaseInOut, animations: { [weak self] _ in
            self?.searchBarTopConstraint.constant = 0
            self?.view.layoutIfNeeded()
        }, completion: nil)

        searchBar.becomeFirstResponder()
    }

    private func updateContactsTableView(scrollsToTop scrollsToTop: Bool = false) {
        dispatch_async(dispatch_get_main_queue()) { [weak self] in
            self?.contactsTableView.reloadData()

            if scrollsToTop {
                self?.contactsTableView.yep_scrollsToTop()
            }
        }
    }

    private func hideKeyboard() {
        searchBar.resignFirstResponder()

        //(tabBarController as? YepTabBarController)?.setTabBarHidden(true, animated: true)
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let userBox = sender as? Box<User> where segue.identifier == "showProfile" {
            let vc = segue.destinationViewController as! ProfileViewController
            if userBox.value.userID != YepUserDefaults.userID.value {
                vc.profileUser = .UserType(userBox.value)
            }
            vc.hidesBottomBarWhenPushed = true
            vc.setBackButtonWithTitle()
            
            // 记录原始的 contactsSearchTransition 以便 pop 后恢复
            contactsSearchTransition = navigationController?.delegate as? ContactsSearchTransition
            
            navigationController?.delegate = originalNavigationControllerDelegate
            
        } else if let discoveredUserBox = sender as? Box<DiscoveredUser> where segue.identifier == "showProfile" {
            let vc = segue.destinationViewController as! ProfileViewController
            vc.profileUser = .DiscoveredUserType(discoveredUserBox.value)
            vc.hidesBottomBarWhenPushed = true
            vc.setBackButtonWithTitle()
            
            // 记录原始的 contactsSearchTransition 以便 pop 后恢复
            contactsSearchTransition = navigationController?.delegate as? ContactsSearchTransition
            
            navigationController?.delegate = originalNavigationControllerDelegate
        }
        
    }
}

// MARK: - UISearchBarDelegate

extension SearchContactsViewController: UISearchBarDelegate {

    func searchBarCancelButtonClicked(searchBar: UISearchBar) {

        searchBar.text = nil
        searchBar.resignFirstResponder()

//        (tabBarController as? YepTabBarController)?.setTabBarHidden(false, animated: true)

        navigationController?.popViewControllerAnimated(true)
    }

    func searchBarSearchButtonClicked(searchBar: UISearchBar) {

        hideKeyboard()
    }

}

// MARK: -  UITableViewDelegate

extension SearchContactsViewController: UIScrollViewDelegate {

    func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { // 然而这里又和 AnimatableSectionModel 不搭配，可以考虑整两个 enum 哈
        
        guard searchControllerIsActive else { return nil }
        
        let header = tableView.dequeueReusableHeaderFooterViewWithIdentifier(SearchContactsViewController.headerIdentifier) as? TableSectionTitleView
        
        switch section {
        case 0:
            header?.titleLabel.text = NSLocalizedString("Friends", comment: "")
        case 1:
            header?.titleLabel.text = NSLocalizedString("Users", comment: "")
        default:
            break
        }
        
        return header
        
    }

    func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        switch searchControllerIsActive {
        case true: return 25
        case false: return 0
        }

    }

}
