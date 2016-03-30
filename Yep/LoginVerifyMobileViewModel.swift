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
    
//    let validatedVerifyCode: Observable<Bool>
    
    let loginEnabled = Variable(false)
    let loginRequesting = Variable(false)
    let loginResult: Observable<LoginUser>
//    let loginInfo = Variable(MobileInfo(mobileNumber: "", area: ""))
    
    let mobileInfo: MobileInfo
    
    private let disposeBag = DisposeBag()
    
    init(
        input: (
        verifyCode: Observable<String>,
        nextTap: Observable<Void>
        ),
        info: MobileInfo
        ) {
        
        mobileInfo = info
        
        let enabled =  input.verifyCode
            .map { $0.characters.count == YepConfig.verifyCodeLength() }
            .shareReplay(1)
        
        enabled
            .bindTo(loginEnabled)
            .addDisposableTo(disposeBag)
        
        let autoLogin = enabled
            .flatMapLatest { enabled -> Observable<Void> in
                return enabled ? Observable.just() : Observable.empty()
            }
        
        let loginRequest = input.nextTap
//            .toObservable()
//            .merge()
            .withLatestFrom(input.verifyCode)
            .shareReplay(1)
        
        loginResult = loginRequest
            .flatMapLatest { rx_loginByMobile(info.mobileNumber, withAreaCode: info.area, verifyCode: $0) }
            .shareReplay(1)
        
        
        [loginRequest.map { _ in true }, loginResult.map { _ in false}]
            .toObservable()
            .merge()
            .bindTo(loginRequesting)
            .addDisposableTo(disposeBag)
        
    }
}
