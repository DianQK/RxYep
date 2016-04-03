//
//  SegueViewController.swift
//  Yep
//
//  Created by nixzhu on 16/1/4.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import UIKit

public class SegueViewController: UIViewController {

    public override func performSegueWithIdentifier(identifier: String, sender: AnyObject?) {

        if let navigationController = navigationController {
            guard navigationController.topViewController == self else {
                return
            }
        }

        super.performSegueWithIdentifier(identifier, sender: sender)
    }
}

extension UIViewController {
    
    public func yep_performSegueWithIdentifier<T>(identifier: String, sender: Box<T>?) {
        
        if let navigationController = navigationController {
            guard navigationController.topViewController == self else {
                return
            }
        }
        
        self.performSegueWithIdentifier(identifier, sender: sender)
    }
    
    
    public func yep_performSegueWithIdentifier(identifier: String, sender: AnyObject?) {
        
        if let navigationController = navigationController {
            guard navigationController.topViewController == self else {
                return
            }
        }
        
        self.performSegueWithIdentifier(identifier, sender: sender)
    }

}