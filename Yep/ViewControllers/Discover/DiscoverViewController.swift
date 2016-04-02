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

class DiscoverViewController: BaseViewController {

    @IBOutlet weak var discoveredUsersCollectionView: DiscoverCollectionView!
    
    @IBOutlet private weak var filterButtonItem: UIBarButtonItem!
    
    @IBOutlet private weak var modeButtonItem: UIBarButtonItem!

    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!
    
    var viewModel: DiscoverViewModel!
    
    let dataSource = RxCollectionViewSectionedReloadDataSource<DiscoverSection>()

    private let NormalUserIdentifier = "DiscoverNormalUserCell"
    private let CardUserIdentifier = "DiscoverCardUserCell"
    private let loadMoreCollectionViewCellID = "LoadMoreCollectionViewCell"
    
    private let refreshControl = UIRefreshControl()

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

        discoveredUsersCollectionView.backgroundColor = UIColor.clearColor()

        discoveredUsersCollectionView.registerNib(UINib(nibName: NormalUserIdentifier, bundle: nil), forCellWithReuseIdentifier: NormalUserIdentifier)
        discoveredUsersCollectionView.registerNib(UINib(nibName: CardUserIdentifier, bundle: nil), forCellWithReuseIdentifier: CardUserIdentifier)
        discoveredUsersCollectionView.registerNib(UINib(nibName: loadMoreCollectionViewCellID, bundle: nil), forCellWithReuseIdentifier: loadMoreCollectionViewCellID)

        refreshControl.tintColor = UIColor.lightGrayColor()
        refreshControl.layer.zPosition = -1 // Make Sure Indicator below the Cells
        discoveredUsersCollectionView.addSubview(refreshControl)

        #if DEBUG
            view.addSubview(discoverFPSLabel)
        #endif
        /// 显示过滤 View
        filterButtonItem.rx_tap
            .subscribeNext { [unowned self] in
                if let window = self.view.window {
                    self.filterView.showInView(window)
                }
            }.addDisposableTo(rx_disposeBag)
        /// LoadMore
        let loadMoreTrigger = rx_sentMessage(#selector(DiscoverViewController.collectionView(_:willDisplayCell:forItemAtIndexPath:)))
            .flatMap { objects -> Driver<Void> in
                let objects = objects as [AnyObject]
                if let _ = objects[1] as? LoadMoreCollectionViewCell {
                    println("load more discovered users")
                    return Driver.just(())
                } else {
                    return Driver.empty()
                }
            }.asDriver(onErrorJustReturn: ())

        viewModel = DiscoverViewModel(input: (
            refreshTrigger: refreshControl.rx_controlEvent(.ValueChanged).asDriver(),
            loadMoreTrigger: loadMoreTrigger,
            filterStyleChanged: filterView.rx_itemSelected.asDriver(onErrorJustReturn: (.Cancel, 0)),
            modeChanged: modeButtonItem.rx_tap.asDriver()
        ))
        
        /// 将过滤选项绑定到 filterView 上
        viewModel.filterItems.asObservable()
            .bindTo(filterView.rx_items)
            .addDisposableTo(rx_disposeBag)
        
        discoveredUsersCollectionView.rx_setDelegate(self)
        
        dataSource.cellFactory = { ds, cv, ip, i in
            switch ds.sectionAtIndex(ip.section).model {
            case .Card:
                let cell = cv.dequeueReusableCellWithReuseIdentifier(self.CardUserIdentifier, forIndexPath: ip) as! DiscoverCardUserCell
                cell.configureWithDiscoveredUser(i.identity.value!, collectionView: cv, indexPath: ip)
                return cell
            case .Normal:
                let cell = cv.dequeueReusableCellWithReuseIdentifier(self.NormalUserIdentifier, forIndexPath: ip) as! DiscoverNormalUserCell
                cell.configureWithDiscoveredUser(i.identity.value!, collectionView: cv, indexPath: ip)
                return cell
            case .LoadMore:
                let cell = cv.dequeueReusableCellWithReuseIdentifier(self.loadMoreCollectionViewCellID, forIndexPath: ip) as! LoadMoreCollectionViewCell
                return cell
            }
        }
        
        /// 切换分类和用户结果改变都应该刷新 collectionView
        Observable.combineLatest(viewModel.discoveredUsers.asObservable(), viewModel.userMode.asObservable()) { users, mode in
            if users.isNotEmpty {
                return [DiscoverSection(model: mode, items: users.map { OptionalHashBox($0) }), DiscoverSection(model: .LoadMore, items: [OptionalHashBox(nil)])]
            } else {
                return [DiscoverSection(model: mode, items: users.map { OptionalHashBox($0) })]
            }
            }
            .bindTo(discoveredUsersCollectionView.rx_itemsWithDataSource(dataSource))
            .addDisposableTo(rx_disposeBag)
        
        /// 点击处理
        discoveredUsersCollectionView
            .rx_modelItemSelected(IdentifiableValue<OptionalHashBox<DiscoveredUser>>)
            .subscribeNext { [unowned self] collectionView, model, item in
                collectionView.deselectItemAtIndexPath(item, animated: true)
                if let user = model.identity.value {
                    self.performSegueWithIdentifier("showProfile", sender: Box(user))
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        /// 将过滤选项绑定到 filterButtonItem 上
        viewModel.discoveredUserSortStyle.asDriver()
            .map { $0.nameWithArrow }
            .drive(filterButtonItem.rx_title)
            .addDisposableTo(rx_disposeBag)
        
        /// 绑定加载状态
        viewModel.isFetching.asObservable()
            .bindTo(activityIndicator.rx_animating)
            .addDisposableTo(rx_disposeBag)
        /// 绑定刷新状态 == 目前只上了结束的状态，刷新似乎不用我们做
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
                default: break
                }
            }
            .addDisposableTo(rx_disposeBag)
        
    }

    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) { // 没有类型检查，果然不好处理 ==
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

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        
        switch dataSource.sectionAtIndex(indexPath.section).model {
        case .Normal, .LoadMore:
            return CGSize(width: UIScreen.mainScreen().bounds.width, height: 80)
        case .Card:
            return CGSize(width: (UIScreen.mainScreen().bounds.width - (10 + 10 + 10)) * 0.5, height: 280)
        }

    }
    
    func collectionView(collectionView: UICollectionView, willDisplayCell cell: UICollectionViewCell, forItemAtIndexPath indexPath: NSIndexPath) {
        
        switch dataSource.sectionAtIndex(indexPath.section).model {
        case .LoadMore:
            if let cell = cell as? LoadMoreCollectionViewCell {
                if !cell.loadingActivityIndicator.isAnimating() {
                    cell.loadingActivityIndicator.startAnimating()
                }
            }
        default: break
        }
    }

    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        
        switch dataSource.sectionAtIndex(section).model {
        case .Normal, .LoadMore:
            return UIEdgeInsetsZero
        case .Card:
            return UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }

}

