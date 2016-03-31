//
//  RegisterPickMobileViewModel.swift
//  Yep
//
//  Created by 宋宋 on 16/3/31.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import RxSwift
import RxCocoa
import RxOptional
import NSObject_Rx

//typealias MobileInfo = (mobileNumber: String, area: String)
// TODO: - 总觉得应该做成一个 ViewModel ，这里的逻辑完全类似于 LoginByMobileViewModel
class RegisterPickMobileViewModel {
    
    let validatedAreaCode: Driver<Bool>
    let validatedMobileNumber: Driver<Bool>
    
    let registerPickMobileEnabled: Driver<Bool>
    /// 验证手机号是否可用状态
    let validateMobileRequesting = Variable(false)
    let validateMobileResult: Driver<RxYepResult<(Bool, String)>>
    /// 注册状态
    let registerMobileRequesting = Variable(false)
    let registerMobileResult: Driver<RxYepResult<Bool>>
    
    let requesting = Variable(false)
    
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
        
        registerPickMobileEnabled = Driver.combineLatest(validatedAreaCode, validatedMobileNumber) { $0 && $1 }
        // FIXME: - Add validated
        let validateMobileRequest = input.nextTap
            .withLatestFrom(Driver.combineLatest(input.mobileNumber, input.areaCode) { MobileInfo(mobileNumber: $0, area: $1) } )
        
        validateMobileResult = validateMobileRequest
            .flatMapLatest { rx_validateMobile($0.0, withAreaCode: $0.1)}
        
        [validateMobileRequest.map { _ in true }, validateMobileResult.map { _ in false }]
            .toObservable()
            .merge()
            .bindTo(validateMobileRequesting)
            .addDisposableTo(disposeBag)
        
        validateMobileRequest
            .asObservable()
            .bindTo(loginInfo)
            .addDisposableTo(disposeBag)
        
        let registerMobileRequest = validateMobileResult.flatMapLatest { result -> Driver<(MobileInfo, String)> in
            switch result {
            case .Success(let result):
                if result.0, let nickname = YepUserDefaults.nickname.value {
                    return Driver.combineLatest(validateMobileRequest, Driver.just(nickname)) { $0 }
                }
                return Driver.empty()
            default:
                return Driver.empty()
            }
        }
        
        registerMobileResult = registerMobileRequest
            .flatMapLatest { rx_registerMobile($0.mobileNumber, withAreaCode: $0.area, nickname: $1) }
        
        [registerMobileRequest.map { _ in true }, registerMobileResult.map { _ in false }]
            .toObservable()
            .merge()
            .bindTo(registerMobileRequesting)
            .addDisposableTo(disposeBag)
        
        Observable.combineLatest(validateMobileRequesting.asObservable(), registerMobileRequesting.asObservable()) { $0 || $1 }
            // TODO: - 这似乎并不是什么好方案
            .debounce(0.1, scheduler: MainScheduler.instance)
            .distinctUntilChanged()
            .bindTo(requesting)
            .addDisposableTo(disposeBag)
        
    }
}
