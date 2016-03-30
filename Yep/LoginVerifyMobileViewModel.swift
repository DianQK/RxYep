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
    let callMeTimer: Observable<Int>
    let callMeTimerEnabled: Observable<Bool>
    
    let calling = Variable(false)
    
    let mobileInfo: MobileInfo
    
    let callMeTriger = PublishSubject<Void>()
    let callMeResult: Driver<RxYepResult<Bool>>
    
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
        
        callMeTimer = Observable.interval(1, scheduler: MainScheduler.instance)
            .flatMapLatest { time in
                return time < YepConfig.callMeInSeconds() ? Observable.just(YepConfig.callMeInSeconds() - time) : Observable.empty()
            }
            .shareReplay(1)
        
        callMeTimerEnabled = callMeTimer.map { $0 == 1 }
            .asObservable()
            .distinctUntilChanged()
        
        let callMeRequest =  callMeTriger.asObservable()
            .withLatestFrom(callMeTimerEnabled)
            .takeWhile { $0 }
            .asDriver(onErrorJustReturn: false)
            .map { _ in info }
        
        callMeResult = callMeRequest.flatMapLatest { rx_sendVerifyCodeOfMobile($0.mobileNumber, withAreaCode: $0.area, useMethod: .Call) }
        // TODO: - 整理 Calling 状态
        [callMeRequest.map { _ in true }.asObservable(), callMeResult.map { _ in false }.asObservable()]
            .toObservable()
            .merge()
            .bindTo(calling)
            .addDisposableTo(disposeBag)
        
    }
}
