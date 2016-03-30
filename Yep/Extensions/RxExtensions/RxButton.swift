//
//  RxButton.swift
//  Yep
//
//  Created by 宋宋 on 16/3/30.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

extension UIButton {
    public var rx_title: AnyObserver<String?> {
        return UIBindingObserver(UIElement: self) { button, text in
            UIView.performWithoutAnimation {
                button.setTitle(text, forState: .Normal)
                button.layoutIfNeeded()
            }
            }.asObserver()
    }
}
