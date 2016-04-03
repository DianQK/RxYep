//
//  PodsHelpYepViewController.swift
//  Yep
//
//  Created by nixzhu on 15/8/31.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import NSObject_Rx

class PodsHelpYepViewController: UITableViewController {

    private let pods: [[String: String]] = [
        [
            "name": "RxSwift",
            "URLString": "https://github.com/ReactiveX/RxSwift",
        ],
        [
            "name": "RealmSwift",
            "URLString": "https://realm.io",
        ],
        [
            "name": "MZFayeClient",
            "URLString": "https://github.com/m1entus/MZFayeClient",
        ],
        [
            "name": "Proposer",
            "URLString": "https://github.com/nixzhu/Proposer",
        ],
        [
            "name": "KeyboardMan",
            "URLString": "https://github.com/nixzhu/KeyboardMan",
        ],
        [
            "name": "Ruler",
            "URLString": "https://github.com/nixzhu/Ruler",
        ],
        [
            "name": "MonkeyKing",
            "URLString": "https://github.com/nixzhu/MonkeyKing",
        ],
        [
            "name": "Navi",
            "URLString": "https://github.com/nixzhu/Navi",
        ],
        [
            "name": "APAddressBook/Swift",
            "URLString": "https://github.com/Alterplay/APAddressBook",
        ],
        [
            "name": "1PasswordExtension",
            "URLString": "https://github.com/AgileBits/onepassword-app-extension",
        ],
        [
            "name": "Kingfisher",
            "URLString": "https://github.com/onevcat/Kingfisher",
        ],
        [
            "name": "FXBlurView",
            "URLString": "https://github.com/nicklockwood/FXBlurView",
        ],
        [
            "name": "TPKeyboardAvoiding",
            "URLString": "https://github.com/michaeltyson/TPKeyboardAvoiding",
        ],
        [
            "name": "DeviceGuru",
            "URLString": "https://github.com/InderKumarRathore/DeviceGuru",
        ],
        [
            "name": "Alamofire",
            "URLString": "https://github.com/Alamofire/Alamofire",
        ],
        [
            "name": "pop",
            "URLString": "https://github.com/facebook/pop",
        ],
    ].sort({ a, b in
        if let
            nameA = a["name"],
            nameB = b["name"] {

                return nameA < nameB
        }

        return true
    })

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("Pods", comment: "")

        tableView.tableFooterView = UIView()
        tableView.dataSource = nil
        tableView.delegate = nil
        
        Observable.just(pods).asObservable()
            .bindTo(tableView.rx_itemsWithCellIdentifier("PodCell")) { _, i, c in
                c.textLabel?.text = i["name"]
            }
            .addDisposableTo(rx_disposeBag)
        
        tableView.rx_modelItemSelected([String: String])
            .subscribeNext { [unowned self] tb, i, ip in
                self.yep_openURL(NSURL(string: i["URLString"]!)!)
                tb.deselectRowAtIndexPath(ip, animated: true)
            }
            .addDisposableTo(rx_disposeBag)
        
    }

}
