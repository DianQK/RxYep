//
//  DiscoverViewController.swift
//  Yep
//
//  Created by NIX on 15/3/16.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import RealmSwift
import RxSwift
import RxCocoa
import RxDataSources
import RxOptional
import NSObject_Rx

typealias DiscoveredUserWithMode = (user: DiscoveredUser, mode: DiscoverUserMode)

class DiscoverViewController: BaseViewController {

    @IBOutlet weak var discoveredUsersCollectionView: DiscoverCollectionView!
    
    @IBOutlet private weak var filterButtonItem: UIBarButtonItem!
    
    @IBOutlet private weak var modeButtonItem: UIBarButtonItem!

    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    
    var viewModel: DiscoverViewModel!

    private let NormalUserIdentifier = "DiscoverNormalUserCell"
    private let CardUserIdentifier = "DiscoverCardUserCell"
    private let loadMoreCollectionViewCellID = "LoadMoreCollectionViewCell"
    // viewModel
    private var userMode: DiscoverUserMode = .Card {
        didSet {
            layout.userMode = userMode
            discoveredUsersCollectionView.reloadData()
        }
    }
    
    private let layout = DiscoverFlowLayout()
    
    private let refreshControl = UIRefreshControl()
    // viewModel
    private var discoveredUserSortStyle: DiscoveredUserSortStyle = .Default {
        didSet {
//            discoveredUsers = []
            discoveredUsersCollectionView.reloadData()
            
            filterButtonItem.title = discoveredUserSortStyle.nameWithArrow

            updateDiscoverUsers(mode: .Static)

            // save discoveredUserSortStyle

            YepUserDefaults.discoveredUserSortStyle.value = discoveredUserSortStyle.rawValue
        }
    }

    private lazy var filterView: RxActionSheetView = RxActionSheetView()

    #if DEBUG
    private lazy var discoverFPSLabel: FPSLabel = FPSLabel()
    #endif

    deinit {
        println("deinit Discover")
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        refreshControl.endRefreshing()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Discover", comment: "")

        view.backgroundColor = UIColor.whiteColor()

        // recover discoveredUserSortStyle if can

        if let
            value = YepUserDefaults.discoveredUserSortStyle.value,
            _discoveredUserSortStyle = DiscoveredUserSortStyle(rawValue: value) {

                discoveredUserSortStyle = _discoveredUserSortStyle

        } else {
            discoveredUserSortStyle = .Default
        }

        discoveredUsersCollectionView.backgroundColor = UIColor.clearColor()
        discoveredUsersCollectionView.setCollectionViewLayout(layout, animated: false)

        discoveredUsersCollectionView.registerNib(UINib(nibName: NormalUserIdentifier, bundle: nil), forCellWithReuseIdentifier: NormalUserIdentifier)
        discoveredUsersCollectionView.registerNib(UINib(nibName: CardUserIdentifier, bundle: nil), forCellWithReuseIdentifier: CardUserIdentifier)
        discoveredUsersCollectionView.registerNib(UINib(nibName: loadMoreCollectionViewCellID, bundle: nil), forCellWithReuseIdentifier: loadMoreCollectionViewCellID)

        userMode = .Card

        refreshControl.tintColor = UIColor.lightGrayColor()
        refreshControl.layer.zPosition = -1 // Make Sure Indicator below the Cells
        discoveredUsersCollectionView.addSubview(refreshControl)

        #if DEBUG
            view.addSubview(discoverFPSLabel)
        #endif
        /// 显示过滤 View
        filterButtonItem.rx_tap.subscribeNext { [unowned self] in
            if let window = self.view.window {
                self.filterView.showInView(window)
            }
            }.addDisposableTo(rx_disposeBag)

        viewModel = DiscoverViewModel(input: (
            refreshTriger: refreshControl.rx_controlEvent(.ValueChanged).asDriver(),
            loadMoreTriger: Driver.empty(),
            filterStyleChanged: filterView.rx_itemSelected.asDriver(onErrorJustReturn: (.Cancel, 0)),
            modeChanged: modeButtonItem.rx_tap.asDriver()
        ))
        
        /// 将过滤选项绑定到 filterView 上
        viewModel.filterItems.asObservable()
            .bindTo(filterView.rx_items)
            .addDisposableTo(rx_disposeBag)
        
        discoveredUsersCollectionView.rx_setDelegate(self)
        
        /// 切换分类和用户结果改变都应该刷新 collectionView
        Observable.combineLatest(viewModel.discoveredUsers.asObservable(), viewModel.userMode.asObservable()) { users, mode in
            return users.map { DiscoveredUserWithMode(user: $0, mode: mode) }
            }
            .bindTo(discoveredUsersCollectionView.rx_itemsWithCellFactory) { [unowned self] cv, row, i in
                let indexPath = NSIndexPath(forRow: row, inSection: 0)
                switch i.mode {
                case .Card:
                    let cell = cv.dequeueReusableCellWithReuseIdentifier(self.CardUserIdentifier, forIndexPath: indexPath) as! DiscoverCardUserCell
                    cell.configureWithDiscoveredUser(i.user, collectionView: cv, indexPath: indexPath)
                    return cell
                case .Normal:
                    let cell = cv.dequeueReusableCellWithReuseIdentifier(self.NormalUserIdentifier, forIndexPath: indexPath) as! DiscoverNormalUserCell
                    cell.configureWithDiscoveredUser(i.user, collectionView: cv, indexPath: indexPath)
                    return cell
                }
                
            }
            .addDisposableTo(rx_disposeBag)
        
        /// 点击处理
        discoveredUsersCollectionView
            .rx_modelItemSelected(DiscoveredUserWithMode)
            .subscribeNext { [unowned self] collectionView, model, item in
                collectionView.deselectItemAtIndexPath(item, animated: true)
                self.performSegueWithIdentifier("showProfile", sender: Box(model.user))
            }
            .addDisposableTo(rx_disposeBag)
        
        /// 将过滤选项绑定到 filterButtonItem 上
        viewModel.discoveredUserSortStyle.asDriver()
            .map { $0.nameWithArrow }
            .drive(filterButtonItem.rx_title)
            .addDisposableTo(rx_disposeBag)
        
        /// 绑定加载状态 == 目前只上了结束的状态，刷新似乎不用我们做
        viewModel.isFetching.asObservable().debug("Fetching")
            .bindTo(activityIndicator.rx_animating)
            .addDisposableTo(rx_disposeBag)
        
        viewModel.isRefreshing.asDriver()
            .driveNext { [unowned self] isRefreshing in
                if !isRefreshing {
                    self.refreshControl.endRefreshing()
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        // 绑定切换 Mode 状态到 modeButtonItem ，事实上你也可以不通过 ViewModel 来做
        viewModel.userMode.asDriver()
            .driveNext { [unowned self] mode in
                switch mode {
                case .Card:
                    self.view.backgroundColor = UIColor.yepBackgroundColor()
                    self.modeButtonItem.image = UIImage(named: "icon_list")
                case .Normal:
                    self.view.backgroundColor = UIColor.whiteColor()
                    self.modeButtonItem.image = UIImage(named: "icon_minicard")
                }
            }
            .addDisposableTo(rx_disposeBag)
        
    }

    // viewModel
    private var currentPageIndex = 1
    // viewModel
    private var isFetching = false
    private enum UpdateMode {
        case Static
        case TopRefresh
        case LoadMore
    }
    private func updateDiscoverUsers(mode mode: UpdateMode, finish: (() -> Void)? = nil) {

        if isFetching {
            return
        }

        isFetching = true
        
        if case .Static = mode {
            activityIndicator.startAnimating()
            view.bringSubviewToFront(activityIndicator)
        }

        if case .LoadMore = mode {
            currentPageIndex += 1

        } else {
            currentPageIndex = 1
        }

        discoverUsers(masterSkillIDs: [], learningSkillIDs: [], discoveredUserSortStyle: discoveredUserSortStyle, inPage: currentPageIndex, withPerPage: 21, failureHandler: { (reason, errorMessage) in
            defaultFailureHandler(reason: reason, errorMessage: errorMessage)

            dispatch_async(dispatch_get_main_queue()) { [weak self] in
                self?.activityIndicator.stopAnimating()
                self?.isFetching = false

                finish?()
            }

        }, completion: { discoveredUsers in

            dispatch_async(dispatch_get_main_queue()) { [weak self] in

                guard let strongSelf = self else {
                    return
                }

                var wayToUpdate: UICollectionView.WayToUpdate = .None

                if case .LoadMore = mode {
//                    let oldDiscoveredUsersCount = strongSelf.discoveredUsers.count
//                    strongSelf.discoveredUsers += discoveredUsers
//                    let newDiscoveredUsersCount = strongSelf.discoveredUsers.count
                    
//                    let indexPaths = Array(oldDiscoveredUsersCount..<newDiscoveredUsersCount).map({ NSIndexPath(forItem: $0, inSection: Section.User.rawValue) })
//                    if !indexPaths.isEmpty {
//                        wayToUpdate = .Insert(indexPaths)
//                    }

                } else {
//                    strongSelf.discoveredUsers = discoveredUsers
                    wayToUpdate = .ReloadData
                }

                strongSelf.activityIndicator.stopAnimating()
                strongSelf.isFetching = false

                finish?()

                wayToUpdate.performWithCollectionView(strongSelf.discoveredUsersCollectionView)
            }
        })
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let discoveredUserBox = sender as? Box<DiscoveredUser> where segue.identifier == "showProfile" {
            let vc = segue.destinationViewController as! ProfileViewController
            
            if discoveredUserBox.value.id != YepUserDefaults.userID.value {
                vc.profileUser = ProfileUser.DiscoveredUserType(discoveredUserBox.value)
            }
            
            vc.setBackButtonWithTitle()
            
            vc.hidesBottomBarWhenPushed = true
        }
        
    }
}

// MARK: UITableViewDelegate

extension DiscoverViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    private enum Section: Int {
        case User
        case LoadMore
    }

    
//    func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
//
//        switch indexPath.section {
//
//        case Section.User.rawValue:
//
//            let discoveredUser = discoveredUsers[indexPath.row]
//
//            switch userMode {
//
//            case .Normal:
//                let cell = cell as! DiscoverNormalUserCell
//                cell.configureWithDiscoveredUser(discoveredUser, collectionView: collectionView, indexPath: indexPath)
//                
//            case .Card:
//                let cell = cell as! DiscoverCardUserCell
//                cell.configureWithDiscoveredUser(discoveredUser, collectionView: collectionView, indexPath: indexPath)
//            }
//
//        case Section.LoadMore.rawValue:
//            if let cell = cell as? LoadMoreCollectionViewCell {
//
//                println("load more discovered users")
//
//                if !cell.loadingActivityIndicator.isAnimating() {
//                    cell.loadingActivityIndicator.startAnimating()
//                }
//
//                updateDiscoverUsers(mode: .LoadMore, finish: { [weak cell] in
//                    cell?.loadingActivityIndicator.stopAnimating()
//                })
//            }
//
//        default:
//            break
//        }
//    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {

        switch indexPath.section {

        case Section.User.rawValue:

            switch userMode {

            case .Normal:
                return CGSize(width: UIScreen.mainScreen().bounds.width, height: 80)

            case .Card:
                return CGSize(width: (UIScreen.mainScreen().bounds.width - (10 + 10 + 10)) * 0.5, height: 280)
            }

        case Section.LoadMore.rawValue:
            return CGSize(width: UIScreen.mainScreen().bounds.width, height: 80)

        default:
            return CGSizeZero
        }
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {

        switch section {

        case Section.User.rawValue:

            switch userMode {

            case .Normal:
                return UIEdgeInsetsZero
                
            case .Card:
                return UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
            }

        case Section.LoadMore.rawValue:
            return UIEdgeInsetsZero

        default:
            return UIEdgeInsetsZero
        }
    }

}

