//
//  LoginByMobileViewModel.swift
//  Yep
//
//  Created by 宋宋 on 16/3/29.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import RxSwift
import RxCocoa
import RxOptional
import NSObject_Rx

typealias MobileInfo = (mobileNumber: String, area: String)

class LoginByMobileViewModel {
    
    
    let validatedAreaCode: Observable<Bool>
    let validatedMobileNumber: Observable<Bool>
    
    let loginVerifyMobileEnabled: Observable<Bool>
    let loginVerifyMobileRequesting = Variable(false)
    let loginVerifyMobileResult: Observable<Bool>
    let loginInfo = Variable(MobileInfo(mobileNumber: "", area: ""))
    
    private let disposeBag = DisposeBag()
    
    init(
        input: (
        areaCode: Observable<String>,
        mobileNumber: Observable<String>,
        nextTap: Observable<Void>
        )
        ) {
        
        validatedAreaCode = input.areaCode.map { $0.isNotEmpty }
        
        validatedMobileNumber = input.mobileNumber.map { $0.isNotEmpty }
        
        loginVerifyMobileEnabled = Observable.combineLatest(validatedAreaCode, validatedMobileNumber) { $0 && $1 }
        
        let loginVerifyMobileRequest = input.nextTap
            .withLatestFrom(Observable.combineLatest(input.mobileNumber, input.areaCode) { MobileInfo(mobileNumber: $0.0, area: $0.1) } )
            .shareReplay(1)
        
        loginVerifyMobileResult = loginVerifyMobileRequest
            .flatMapLatest {
                rx_sendVerifyCodeOfMobile($0.0, withAreaCode: $0.1, useMethod: .SMS)
        }.shareReplay(1)
        
        [loginVerifyMobileRequest.map { _ in true }, loginVerifyMobileResult.map { _ in false }]
            .toObservable()
            .merge()
            .bindTo(loginVerifyMobileRequesting)
            .addDisposableTo(disposeBag)
        
        loginVerifyMobileRequest
            .bindTo(loginInfo)
            .addDisposableTo(disposeBag)
        
    }
}