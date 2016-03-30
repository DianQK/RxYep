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
        
        
        viewModel.callMeTimer
            .map { NSLocalizedString("Call me", comment: "") + ($0 > 1 ? " (\($0))" : "") }
            .bindTo(callMeButton.rx_title)
            .addDisposableTo(rx_disposeBag)
        
        [viewModel.callMeTimerEnabled, viewModel.calling.asObservable().map { !$0 }]
            .toObservable()
            .merge()
            .bindTo(callMeButton.rx_enabled)
            .addDisposableTo(rx_disposeBag)
        
        viewModel.calling.asObservable()
            .map { NSLocalizedString(($0 ? "Calling" : "Call Me"), comment: "") }
            .bindTo(callMeButton.rx_title)
            .addDisposableTo(rx_disposeBag)
        
        callMeButton.rx_tap
            .bindTo(viewModel.callMeTriger)
            .addDisposableTo(rx_disposeBag)
        // 不想接电话，先不测这里了~
        viewModel.callMeResult
            .driveNext { [unowned self] result in
                switch result {
                case .Success(let success): println("resendVoiceVerifyCode \(success)")
                case .Failure(let error):  YepAlert.alertSorry(message: error.errorMessage, inViewController: self)
                }
            }
            .addDisposableTo(rx_disposeBag)
        
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        verifyCodeTextField.becomeFirstResponder()
    }

    // MARK: Actions

    @objc private func activeAgain(notification: NSNotification) {
        verifyCodeTextField.becomeFirstResponder()
    }

}
