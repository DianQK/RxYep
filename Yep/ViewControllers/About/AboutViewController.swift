//
//  AboutViewController.swift
//  Yep
//
//  Created by nixzhu on 15/8/28.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import Ruler
import RxSwift
import RxCocoa
import NSObject_Rx

class AboutViewController: UIViewController {

    @IBOutlet private weak var appLogoImageView: UIImageView!
    @IBOutlet private weak var appLogoImageViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var appNameLabel: UILabel!
    @IBOutlet private weak var appNameLabelTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var appVersionLabel: UILabel!
    
    @IBOutlet private weak var aboutTableView: UITableView!
    @IBOutlet private weak var aboutTableViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet private weak var copyrightLabel: UILabel!

    private let aboutCellID = "AboutCell"

    private let rowHeight: CGFloat = Ruler.iPhoneVertical(50, 60, 60, 60).value
    
    private enum Row {
        case Pods, Rate, Terms
    }

    private let aboutAnnotations: [(Row, String)] = [
        (.Pods, NSLocalizedString("Pods help Yep", comment: "")),
        (.Rate, NSLocalizedString("Rate Yep on App Store", comment: "")),
        (.Terms, NSLocalizedString("Terms of Service", comment: ""))
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("About", comment: "")

        appLogoImageViewTopConstraint.constant = Ruler.iPhoneVertical(0, 20, 40, 60).value
        appNameLabelTopConstraint.constant = Ruler.iPhoneVertical(10, 20, 20, 20).value

        appNameLabel.textColor = UIColor.yepTintColor()

        if let
            releaseVersionNumber = NSBundle.releaseVersionNumber,
            buildVersionNumber = NSBundle.buildVersionNumber {
                appVersionLabel.text = NSLocalizedString("Version", comment: "") + " " + releaseVersionNumber + " (\(buildVersionNumber))"
        }

        aboutTableView.registerNib(UINib(nibName: aboutCellID, bundle: nil), forCellReuseIdentifier: aboutCellID)
        aboutTableView.rowHeight = rowHeight
        aboutTableViewHeightConstraint.constant = rowHeight * CGFloat(aboutAnnotations.count) + 1
        
        Observable.just(aboutAnnotations)
            .bindTo(aboutTableView.rx_itemsWithCellIdentifier(aboutCellID, cellType: AboutCell.self)) { _, i, c in
                c.annotationLabel.text = i.1
            }
            .addDisposableTo(rx_disposeBag)
        
        aboutTableView.rx_modelItemSelected((Row, String))
            .subscribeNext { [unowned self] tv, i, ip in
                switch i.0 {
                case .Pods:
                    self.yep_performSegueWithIdentifier("showPodsHelpYep", sender: nil)
                case .Rate:
                    UIApplication.sharedApplication().openURL(NSURL(string: YepConfig.appURLString)!)
                case .Terms:
                    if let URL = NSURL(string: YepConfig.termsURLString) {
                        self.yep_openURL(URL)
                    }
                }
                tv.deselectRowAtIndexPath(ip, animated: true)
            }
            .addDisposableTo(rx_disposeBag)
    }

}
