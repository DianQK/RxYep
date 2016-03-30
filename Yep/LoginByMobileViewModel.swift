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
// 总觉得应该做成一个 ViewModel
class LoginByMobileViewModel {
    
    let validatedAreaCode: Driver<Bool>
    let validatedMobileNumber: Driver<Bool>
    
    let loginVerifyMobileEnabled: Driver<Bool>
    let loginVerifyMobileRequesting = Variable(false)
    let loginVerifyMobileResult: Driver<RxYepResult<Bool>>
    let loginInfo = Variable(MobileInfo(mobileNumber: "", area: ""))
    
    private let disposeBag = DisposeBag()
    
    init(
        input: (
        areaCode: Driver<String>,
        mobileNumber: Driver<String>,
        nextTap: Driver<Void>
        )
        ) {
        
        validatedAreaCode = input.areaCode.map { $0.isNotEmpty }
        
        validatedMobileNumber = input.mobileNumber.map { $0.isNotEmpty }
        
        loginVerifyMobileEnabled = Driver.combineLatest(validatedAreaCode, validatedMobileNumber) { $0 && $1 }
        // FIXME: - Add validated
        let loginVerifyMobileRequest = input.nextTap
            .withLatestFrom(Driver.combineLatest(input.mobileNumber, input.areaCode) { MobileInfo(mobileNumber: $0, area: $1) } )
        
        loginVerifyMobileResult = loginVerifyMobileRequest
            .flatMapLatest { rx_sendVerifyCodeOfMobile($0.0, withAreaCode: $0.1, useMethod: .SMS) }
        
        [loginVerifyMobileRequest.map { _ in true }, loginVerifyMobileResult.map { _ in false }]
            .toObservable()
            .merge()
            .bindTo(loginVerifyMobileRequesting)
            .addDisposableTo(disposeBag)
        
        loginVerifyMobileRequest
            .asObservable()
            .bindTo(loginInfo)
            .addDisposableTo(disposeBag)
        
    }
}