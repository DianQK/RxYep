//
//  FriendsInContactsViewController.swift
//  Yep
//
//  Created by NIX on 15/6/1.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxDataSources
import RxOptional
import NSObject_Rx

class FriendsInContactsViewController: UIViewController {

    struct Notification {
        static let NewFriends = "NewFriendsInContactsNotification"
    }

    @IBOutlet private weak var friendsTableView: UITableView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    var viewModel: FriendsInContactsViewModel!
    
    private let cellIdentifier = "ContactsCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Available Friends", comment: "")

        friendsTableView.separatorColor = UIColor.yepCellSeparatorColor()
        friendsTableView.separatorInset = YepConfig.ContactsCell.separatorInset
        
        friendsTableView.registerNib(UINib(nibName: cellIdentifier, bundle: nil), forCellReuseIdentifier: cellIdentifier)
        friendsTableView.rowHeight = 80
        friendsTableView.tableFooterView = UIView()
        
        viewModel = FriendsInContactsViewModel()
        /// 结果绑定到 TableView
        viewModel.elements.asObservable()
            .bindTo(friendsTableView.rx_itemsWithCellIdentifier(cellIdentifier, cellType: ContactsCell.self)) { _, discoveredUser, cell in
                cell.configureWithDiscoveredUser(discoveredUser)
            }
            .addDisposableTo(rx_disposeBag)
        
        /// 如果没有结果就显示没有咯
        viewModel.elements.asObservable()
            .skip(1) // 上黑科技解决加载问题，毕竟第一次的空是不需要的
            .map { $0.isEmpty }
            .subscribeNext { isEmpty in
                switch isEmpty {
                case true:
                    self.friendsTableView.tableFooterView = InfoView(NSLocalizedString("No more new friends.", comment: ""))
                case false:
                    NSNotificationCenter.defaultCenter().postNotificationName(Notification.NewFriends, object: nil)
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        /// 绑定加载状态
        viewModel.isLoading.asObservable()
            .bindTo(activityIndicator.rx_animating)
            .addDisposableTo(rx_disposeBag)
        
        /// 点击事件
        friendsTableView.rx_modelItemSelected(DiscoveredUser)
            .subscribeNext { [unowned self] tv, i, ip in
                self.yep_performSegueWithIdentifier("showProfile", sender: Box(i))
                tv.deselectRowAtIndexPath(ip, animated: true)
            }
            .addDisposableTo(rx_disposeBag)
        
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
