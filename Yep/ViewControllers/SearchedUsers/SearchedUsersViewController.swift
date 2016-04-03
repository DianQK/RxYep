//
//  SearchedUsersViewController.swift
//  Yep
//
//  Created by NIX on 15/5/22.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import NSObject_Rx

class SearchedUsersViewController: UIViewController, NavigationBarAutoShowable {

    var searchText = "NIX"

    @IBOutlet private weak var searchedUsersTableView: UITableView!
    @IBOutlet private weak var activityIndicator: UIActivityIndicatorView!

    private static let cellIdentifier = "ContactsCell"
    
    private var viewModel: SearchedUsersViewModel!
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        yepAutoShowNavigationBar()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Search", comment: "") + " \"\(searchText)\""

        searchedUsersTableView.registerNib(UINib(nibName: SearchedUsersViewController.cellIdentifier, bundle: nil), forCellReuseIdentifier: SearchedUsersViewController.cellIdentifier)
        searchedUsersTableView.rowHeight = 80

        searchedUsersTableView.separatorColor = UIColor.yepCellSeparatorColor()
        searchedUsersTableView.separatorInset = YepConfig.ContactsCell.separatorInset

//        activityIndicator.startAnimating()

        viewModel = SearchedUsersViewModel(searchText: searchText)
        
        viewModel.isSearching.asObservable()
            .bindTo(activityIndicator.rx_animating)
            .addDisposableTo(rx_disposeBag)
        
        viewModel.notFoundUsers.asDriver()
            .driveNext { [unowned self] notFoundUsers in
                switch notFoundUsers {
                case true: self.searchedUsersTableView.tableFooterView = InfoView(NSLocalizedString("No search results.", comment: ""))
                case false: self.searchedUsersTableView.tableFooterView = UIView()
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        viewModel.searchedUser.asObservable()
            .bindTo(searchedUsersTableView.rx_itemsWithCellIdentifier(SearchedUsersViewController.cellIdentifier, cellType: ContactsCell.self)) { _, i, c in
                c.configureWithDiscoveredUser(i)
            }
            .addDisposableTo(rx_disposeBag)
        
        searchedUsersTableView.rx_modelItemSelected(DiscoveredUser)
            .subscribeNext { [unowned self] tb, i, ip in
                self.performSegueWithIdentifier("showProfile", sender: Box(i))
                tb.deselectRowAtIndexPath(ip, animated: true)
            }
            .addDisposableTo(rx_disposeBag)
        
    }

    // MARK: Navigation

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
