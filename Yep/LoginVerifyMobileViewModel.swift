//
//  LoginVerifyMobileViewModel.swift
//  Yep
//
//  Created by 宋宋 on 16/3/30.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import RxSwift
import RxCocoa
import RxOptional
import NSObject_Rx

// 需要 Next 验证、发送验证码、自动验证输入（与 Next 合并）
class LoginVerifyMobileViewModel {
    
    let loginEnabled = Variable(false)
    let loginRequesting = Variable(false)
    let loginResult: Driver<RxYepResult<LoginUser>>
    
    let mobileInfo: MobileInfo
    
    private let disposeBag = DisposeBag()
    
    init(
        input: (
        verifyCode: Driver<String>,
        nextTap: Driver<Void>
        ),
        info: MobileInfo
        ) {
        
        mobileInfo = info
        
        let enabled =  input.verifyCode
            .map { $0.characters.count == YepConfig.verifyCodeLength() }
        
        enabled.asObservable()
            .bindTo(loginEnabled)
            .addDisposableTo(disposeBag)
        
        let autoLogin = enabled
            .flatMapLatest { enabled -> Driver<Void> in
                return enabled ? Driver.just() : Driver.empty()
            }
        
        let loginRequest = [input.nextTap, autoLogin]
            .toObservable().merge()
            .asDriver(onErrorJustReturn: ())
            .withLatestFrom(input.verifyCode)
        
        loginResult = loginRequest
            .flatMapLatest { rx_loginByMobile(info.mobileNumber, withAreaCode: info.area, verifyCode: $0) }
        
        
        [loginRequest.map { _ in true }, loginResult.map { _ in false}]
            .toObservable()
            .merge()
            .bindTo(loginRequesting)
            .addDisposableTo(disposeBag)
        
    }
}
