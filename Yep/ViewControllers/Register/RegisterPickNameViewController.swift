//
//  RegisterPickNameViewController.swift
//  Yep
//
//  Created by NIX on 15/3/16.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import Ruler
import RxSwift
import RxCocoa
import NSObject_Rx
import RxOptional

class RegisterPickNameViewController: BaseViewController {

    @IBOutlet private weak var pickNamePromptLabel: UILabel!
    @IBOutlet private weak var pickNamePromptLabelTopConstraint: NSLayoutConstraint!

    @IBOutlet private weak var promptTermsLabel: UILabel!

    @IBOutlet private weak var nameTextField: BorderTextField!
    @IBOutlet private weak var nameTextFieldTopConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        animatedOnNavigationBar = false

        view.backgroundColor = UIColor.yepViewBackgroundColor()

        navigationItem.titleView = NavigationTitleLabel(title: NSLocalizedString("Sign up", comment: ""))
        
        let nextButton = UIBarButtonItem()
        nextButton.title = NSLocalizedString("Next", comment: "")

        navigationItem.rightBarButtonItem = nextButton

        pickNamePromptLabel.text = NSLocalizedString("What's your name?", comment: "")

        let text = NSLocalizedString("By tapping Next you agree to our terms.", comment: "")
        let textAttributes: [String: AnyObject] = [
            NSFontAttributeName: UIFont.systemFontOfSize(14),
            NSForegroundColorAttributeName: UIColor.grayColor(),
        ]
        let attributedText = NSMutableAttributedString(string: text, attributes: textAttributes)
        let termsAttributes: [String: AnyObject] = [
            NSForegroundColorAttributeName: UIColor.yepTintColor(),
            NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue,
        ]
        let tapRange = (text as NSString).rangeOfString(NSLocalizedString("terms", comment: ""))
        attributedText.addAttributes(termsAttributes, range: tapRange)

        promptTermsLabel.attributedText = attributedText
        promptTermsLabel.textAlignment = .Center
        promptTermsLabel.alpha = 0.5

        promptTermsLabel.userInteractionEnabled = true
        let tap = UITapGestureRecognizer()
        promptTermsLabel.addGestureRecognizer(tap)

        nameTextField.backgroundColor = UIColor.whiteColor()
        nameTextField.textColor = UIColor.yepInputTextColor()
        nameTextField.placeholder = " "//NSLocalizedString("Nickname", comment: "")

        pickNamePromptLabelTopConstraint.constant = Ruler.iPhoneVertical(30, 50, 60, 60).value
        nameTextFieldTopConstraint.constant = Ruler.iPhoneVertical(30, 40, 50, 50).value

        nextButton.enabled = false
        
        let trimmingNameText = nameTextField.rx_text
            .map { $0.trimming(.WhitespaceAndNewline) }
            .shareReplay(1)
        
        trimmingNameText.map { $0.isNotEmpty }
            .bindNext { [unowned self] in
            nextButton.enabled = $0
            self.promptTermsLabel.alpha = $0 ? 1.0 : 0.5
            }
            .addDisposableTo(rx_disposeBag)
        // 返回和点击 Next 都应该进入下一步
        [nameTextField.rx_controlEvent([.EditingDidEndOnExit, .EditingDidEnd]), nextButton.rx_tap]
            .toObservable()
            .merge()
            .withLatestFrom(trimmingNameText)
            .filter { $0.isNotEmpty }
            .subscribeNext { [unowned self] in
                YepUserDefaults.nickname.value = $0
                self.performSegueWithIdentifier("showRegisterPickMobile", sender: nil)
            }
            .addDisposableTo(rx_disposeBag)
        
        tap.rx_event
            .subscribeNext { [unowned self] _ in
                if let URL = NSURL(string: YepConfig.termsURLString) {
                    self.yep_openURL(URL)
                }
            }
            .addDisposableTo(rx_disposeBag)
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        nameTextField.becomeFirstResponder()
    }

}