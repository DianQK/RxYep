//
//  LoginByMobileViewController.swift
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

class LoginByMobileViewController: BaseViewController {

    @IBOutlet private weak var pickMobileNumberPromptLabel: UILabel!
    @IBOutlet private weak var pickMobileNumberPromptLabelTopConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var areaCodeTextField: BorderTextField!
    @IBOutlet private weak var areaCodeTextFieldWidthConstraint: NSLayoutConstraint!

    @IBOutlet private weak var mobileNumberTextField: BorderTextField!
    @IBOutlet private weak var mobileNumberTextFieldTopConstraint: NSLayoutConstraint!
    
    var viewModel: LoginByMobileViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        animatedOnNavigationBar = false

        view.backgroundColor = UIColor.yepViewBackgroundColor()

        navigationItem.titleView = NavigationTitleLabel(title: NSLocalizedString("Login", comment: ""))
        
        let nextButton = UIBarButtonItem()
        nextButton.title = NSLocalizedString("Next", comment: "")
        nextButton.style = .Plain
        
        navigationItem.rightBarButtonItem = nextButton
        
        pickMobileNumberPromptLabel.text = NSLocalizedString("What's your number?", comment: "")
        
        areaCodeTextField.text = NSTimeZone.areaCode
        areaCodeTextField.backgroundColor = UIColor.whiteColor()
        
        mobileNumberTextField.placeholder = ""
        mobileNumberTextField.backgroundColor = UIColor.whiteColor()
        mobileNumberTextField.textColor = UIColor.yepInputTextColor()
        
        pickMobileNumberPromptLabelTopConstraint.constant = Ruler.iPhoneVertical(30, 50, 60, 60).value
        mobileNumberTextFieldTopConstraint.constant = Ruler.iPhoneVertical(30, 40, 50, 50).value
        
        viewModel = LoginByMobileViewModel(input: (
            areaCode: areaCodeTextField.rx_text.asDriver(),
            mobileNumber: mobileNumberTextField.rx_text.asDriver(),
            nextTap: nextButton.rx_tap.asDriver()))
        
        // 是否可以去验证
        viewModel.loginVerifyMobileEnabled.asObservable()
            .bindTo(nextButton.rx_enabled)
            .addDisposableTo(rx_disposeBag)
        
        // 观察验证状态
        viewModel.loginVerifyMobileRequesting.asObservable()
            .subscribeNext { [unowned self] in
                switch $0 {
                case true:
                    YepHUD.showActivityIndicator()
                    self.view.endEditing(true)
                case false: YepHUD.hideActivityIndicator()
                }
            }
            .addDisposableTo(rx_disposeBag)
        
        viewModel.loginVerifyMobileResult.driveNext { [weak self] result in
            switch result {
            case .Success(let result) where result == true:
                self?.showLoginVerifyMobile()
            case .Success(let result) where result == false:
                YepAlert.alertSorry(message: NSLocalizedString("Failed to send verification code!", comment: ""), inViewController: self, withDismissAction: { [weak self] in
                    self?.mobileNumberTextField.becomeFirstResponder()
                    })
            case .Failure(let error):
                YepAlert.alertSorry(message: error.errorMessage, inViewController: self, withDismissAction: { [weak self] in
                    self?.mobileNumberTextField.becomeFirstResponder()
                    })
            default: break
            }
            }.addDisposableTo(rx_disposeBag)
        
        areaCodeTextField
            .rx_controlEvent([.EditingChanged, .EditingDidBegin])
            .subscribeNext { [unowned self] in
                self.adjustAreaCodeTextFieldWidth()
            }
            .addDisposableTo(rx_disposeBag)

        areaCodeTextField.rx_controlEvent([.EditingDidEnd, .EditingDidEndOnExit])
            .subscribeNext { [unowned self] in
            // TODO: - request
                self.view.layoutIfNeeded()
                UIView.animateWithDuration(0.1, delay: 0.0, options: .CurveEaseInOut, animations: { _ in
                    self.areaCodeTextFieldWidthConstraint.constant = 60
                    }, completion: nil)
            }
            .addDisposableTo(rx_disposeBag)
        
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        mobileNumberTextField.becomeFirstResponder()
    }

    // MARK: Actions

    private func adjustAreaCodeTextFieldWidth() {
        guard let text = areaCodeTextField.text else {
            return
        }

        let size = text.sizeWithAttributes(areaCodeTextField.editing ? areaCodeTextField.typingAttributes : areaCodeTextField.defaultTextAttributes)

        let width = 32 + (size.width + 22) + 20
        areaCodeTextFieldWidthConstraint.constant = max(width, 100)
        UIView.animateWithDuration(0.1, delay: 0.0, options: .CurveEaseInOut, animations: { _ in
            self.view.layoutIfNeeded()
        }, completion: nil)
    }

    private func showLoginVerifyMobile() {
        guard let areaCode = areaCodeTextField.text, mobile = mobileNumberTextField.text else {
            return
        }
        self.performSegueWithIdentifier("showLoginVerifyMobile", sender: ["mobile" : mobile, "areaCode": areaCode])
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let info = sender as? [String: String] where segue.identifier == "showLoginVerifyMobile" {
            let vc = segue.destinationViewController as! LoginVerifyMobileViewController
            vc.mobileInfo = MobileInfo(mobileNumber: info["mobile"]!, area: info["areaCode"]!)
        }
    }

}
