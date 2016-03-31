//
//  RegisterPickMobileViewController.swift
//  Yep
//
//  Created by NIX on 15/3/17.
//  Copyright (c) 2015年 Catch Inc. All rights reserved.
//

import UIKit
import Ruler
import RxSwift
import RxCocoa
import NSObject_Rx
import RxOptional

class RegisterPickMobileViewController: SegueViewController {

    @IBOutlet private weak var pickMobileNumberPromptLabel: UILabel!
    @IBOutlet private weak var pickMobileNumberPromptLabelTopConstraint: NSLayoutConstraint!

    @IBOutlet private weak var areaCodeTextField: BorderTextField!
    @IBOutlet private weak var areaCodeTextFieldWidthConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var mobileNumberTextField: BorderTextField!
    @IBOutlet private weak var mobileNumberTextFieldTopConstraint: NSLayoutConstraint!
    
    var viewModel: RegisterPickMobileViewModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor.yepViewBackgroundColor()

        navigationItem.titleView = NavigationTitleLabel(title: NSLocalizedString("Sign up", comment: ""))
        
        let nextButton = UIBarButtonItem()
        nextButton.title = NSLocalizedString("Next", comment: "")
        nextButton.style = .Plain

        navigationItem.rightBarButtonItem = nextButton

        pickMobileNumberPromptLabel.text = NSLocalizedString("What's your number?", comment: "")

        areaCodeTextField.text = NSTimeZone.areaCode
        areaCodeTextField.backgroundColor = UIColor.whiteColor()

        //mobileNumberTextField.placeholder = ""
        mobileNumberTextField.backgroundColor = UIColor.whiteColor()
        mobileNumberTextField.textColor = UIColor.yepInputTextColor()

        pickMobileNumberPromptLabelTopConstraint.constant = Ruler.iPhoneVertical(30, 50, 60, 60).value
        mobileNumberTextFieldTopConstraint.constant = Ruler.iPhoneVertical(30, 40, 50, 50).value

        nextButton.enabled = false
        
        viewModel = RegisterPickMobileViewModel(input: (
            areaCode: areaCodeTextField.rx_text.asDriver(),
            mobileNumber: mobileNumberTextField.rx_text.asDriver(),
            nextTap: nextButton.rx_tap.asDriver()))
        
        viewModel.registerPickMobileEnabled.asDriver()
            .drive(nextButton.rx_enabled)
            .addDisposableTo(rx_disposeBag)
        
        viewModel.requesting.asDriver()
            .driveNext { [unowned self] in
                switch $0 {
                case true:
                    self.view.endEditing(true)
                    YepHUD.showActivityIndicator()
                case false:
                    YepHUD.hideActivityIndicator()
                }
            }
            .addDisposableTo(rx_disposeBag)
        /// 验证手机号结果
        viewModel.validateMobileResult.driveNext { result in
            switch result {
            case .Success(let success) where success.0 == false:
                println("ValidateMobile: \(success.1)")
//                YepHUD.hideActivityIndicator()
                nextButton.enabled = false
                YepAlert.alertSorry(message: success.1, inViewController: self) {
                    self.mobileNumberTextField.becomeFirstResponder()
                }
            case .Failure(let error):
                defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
            default: break
            }
            }
            .addDisposableTo(rx_disposeBag)
        // TODO: -
        viewModel.registerMobileResult
            .driveNext { result in
            switch result {
            case .Success(let created) where created:
                self.showRegisterVerifyMobile()
            case .Success(let created) where !created:
                nextButton.enabled = false
                YepAlert.alertSorry(message: "registerMobile failed", inViewController: self) { [weak self] in
                    self?.mobileNumberTextField.becomeFirstResponder()
                    }
            case .Failure(let error):
                defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
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

        UIView.animateWithDuration(0.1, delay: 0.0, options: .CurveEaseInOut, animations: { _ in
            self.areaCodeTextFieldWidthConstraint.constant = max(width, 100)
            self.view.layoutIfNeeded()
        }, completion: { finished in
        })
    }
    
    private func showRegisterVerifyMobile() {
        guard let areaCode = areaCodeTextField.text, mobile = mobileNumberTextField.text else {
            return
        }
        self.performSegueWithIdentifier("showRegisterVerifyMobile", sender: ["mobile" : mobile, "areaCode": areaCode])
    }

    // MARK: Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        if let info = sender as? [String: String] where segue.identifier == "showRegisterVerifyMobile" {
                let vc = segue.destinationViewController as! RegisterVerifyMobileViewController
                vc.mobile = info["mobile"]
                vc.areaCode = info["areaCode"]
        }
    }

}
