//
//  LoginVerifyMobileViewController.swift
//  Yep
//
//  Created by NIX on 15/3/17.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import Ruler
import RxSwift
import RxCocoa
import RxOptional
import NSObject_Rx

class LoginVerifyMobileViewController: UIViewController {
    
    var mobileInfo: MobileInfo!
    
    var viewModel: LoginVerifyMobileViewModel!

    @IBOutlet private weak var verifyMobileNumberPromptLabel: UILabel!
    @IBOutlet private weak var verifyMobileNumberPromptLabelTopConstraint: NSLayoutConstraint!

    @IBOutlet private weak var phoneNumberLabel: UILabel!

    @IBOutlet private weak var verifyCodeTextField: BorderTextField!
    @IBOutlet private weak var verifyCodeTextFieldTopConstraint: NSLayoutConstraint!

    @IBOutlet private weak var callMePromptLabel: UILabel!
    @IBOutlet private weak var callMeButton: UIButton!
    @IBOutlet private weak var callMeButtonTopConstraint: NSLayoutConstraint!

    private lazy var callMeTimer: NSTimer = {
        let timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(LoginVerifyMobileViewController.tryCallMe(_:)), userInfo: nil, repeats: true)
        return timer
    }()

    private var callMeInSeconds = YepConfig.callMeInSeconds()


    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.yepViewBackgroundColor()

        navigationItem.titleView = NavigationTitleLabel(title: NSLocalizedString("Login", comment: ""))
        
        let nextButton = UIBarButtonItem()
        nextButton.title = NSLocalizedString("Next", comment: "")
        nextButton.style = .Plain

        navigationItem.rightBarButtonItem = nextButton

        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(LoginVerifyMobileViewController.activeAgain(_:)), name: AppDelegate.Notification.applicationDidBecomeActive, object: nil)
        
        verifyMobileNumberPromptLabel.text = NSLocalizedString("Input verification code sent to", comment: "")
        phoneNumberLabel.text = "+" + mobileInfo.area + " " + mobileInfo.mobileNumber

        verifyCodeTextField.placeholder = " "
        verifyCodeTextField.backgroundColor = UIColor.whiteColor()
        verifyCodeTextField.textColor = UIColor.yepInputTextColor()

        callMePromptLabel.text = NSLocalizedString("Didn't get it?", comment: "")
        callMeButton.setTitle(NSLocalizedString("Call me", comment: ""), forState: .Normal)

        verifyMobileNumberPromptLabelTopConstraint.constant = Ruler.iPhoneVertical(30, 50, 60, 60).value
        verifyCodeTextFieldTopConstraint.constant = Ruler.iPhoneVertical(30, 40, 50, 50).value
        callMeButtonTopConstraint.constant = Ruler.iPhoneVertical(10, 20, 40, 40).value
        
        
        viewModel = LoginVerifyMobileViewModel(input: (
            verifyCode: verifyCodeTextField.rx_text.asDriver(),
            nextTap: nextButton.rx_tap.asDriver()),
                                                info: mobileInfo)
        
        viewModel.loginEnabled.asObservable()
            .bindTo(nextButton.rx_enabled)
            .addDisposableTo(rx_disposeBag)
        
        viewModel.loginRequesting.asObservable()
            .subscribeNext { [unowned self] in
                switch $0 {
                case true:
                    YepHUD.showActivityIndicator()
                    self.view.endEditing(true)
                case false: YepHUD.hideActivityIndicator()
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        viewModel.loginResult.driveNext { [weak self] result in
            switch result {
            case .Success(let loginUser):
                saveTokenAndUserInfoOfLoginUser(loginUser)
                syncMyInfoAndDoFurtherAction { }
                if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
                    appDelegate.startMainStory()
                }
            case .Failure(let error):
                defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
                if let errorMessage = error.errorMessage {
                    self?.navigationItem.rightBarButtonItem?.enabled = false // FIXME: -
                    YepAlert.alertSorry(message: errorMessage, inViewController: self) {
                        self?.verifyCodeTextField.becomeFirstResponder()
                    }
                }
            }
            }.addDisposableTo(rx_disposeBag)
        
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        callMeButton.enabled = false
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        verifyCodeTextField.becomeFirstResponder()

        callMeTimer.fire()
    }

    // MARK: Actions

    @objc private func activeAgain(notification: NSNotification) {
        verifyCodeTextField.becomeFirstResponder()
    }
    
    @objc private func tryCallMe(timer: NSTimer) {
        let haveAppropriateInput = true
        if !haveAppropriateInput {
            if callMeInSeconds > 1 {
                let callMeInSecondsString = NSLocalizedString("Call me", comment: "") + " (\(callMeInSeconds))"

                UIView.performWithoutAnimation {
                    self.callMeButton.setTitle(callMeInSecondsString, forState: .Normal)
                    self.callMeButton.layoutIfNeeded()
                }

            } else {
                UIView.performWithoutAnimation {
                    self.callMeButton.setTitle(NSLocalizedString("Call me", comment: ""), forState: .Normal)
                    self.callMeButton.layoutIfNeeded()
                }

                callMeButton.enabled = true
            }
        }

        if (callMeInSeconds > 1) {
            callMeInSeconds -= 1
        }
    }

    @IBAction private func callMe(sender: UIButton) {
        
        callMeTimer.invalidate()

        UIView.performWithoutAnimation {
            self.callMeButton.setTitle(NSLocalizedString("Calling", comment: ""), forState: .Normal)
            self.callMeButton.layoutIfNeeded()
        }

        delay(5) {
            UIView.performWithoutAnimation {
                self.callMeButton.setTitle(NSLocalizedString("Call me", comment: ""), forState: .Normal)
                self.callMeButton.layoutIfNeeded()
            }
        }

//        sendVerifyCodeOfMobile(mobile, withAreaCode: areaCode, useMethod: .Call, failureHandler: { [weak self] reason, errorMessage in
//            defaultFailureHandler(reason: reason, errorMessage: errorMessage)
//
//            if let errorMessage = errorMessage {
//
//                YepAlert.alertSorry(message: errorMessage, inViewController: self)
//
//                dispatch_async(dispatch_get_main_queue()) {
//                    UIView.performWithoutAnimation {
//                        self?.callMeButton.setTitle(NSLocalizedString("Call me", comment: ""), forState: .Normal)
//                        self?.callMeButton.layoutIfNeeded()
//                    }
//                }
//            }
//
//        }, completion: { success in
//            println("resendVoiceVerifyCode \(success)")
//        })
    }

}

extension LoginVerifyMobileViewController: UITextFieldDelegate {

    /*
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if haveAppropriateInput {
            login()
        }
        
        return true
    }
    */
}

