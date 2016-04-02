//
//  FriendsInContactsViewModel.swift
//  Yep
//
//  Created by 宋宋 on 16/4/2.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import RxSwift
import RxCocoa
import APAddressBook

class FriendsInContactsViewModel {
    
    let elements = Variable<[DiscoveredUser]>([])
    
    let isLoading = Variable(false)
    
    let disposeBag = DisposeBag()
    
    init(addressBook: APAddressBook) { // 这就是一个比较糟糕的设计了 ==
        
        let request = addressBook.rx_loadContacts()
            .map {
                $0.flatMap { contact -> (name: String, numbers: [String])? in
                    if let name = contact.name?.compositeName, phones = contact.phones {
                        return (name: name, numbers: phones.flatMap { $0.number })          // 在这里过滤所有有 number 的
                    } else {
                        return nil
                    }
                    }
                    .flatMap { contact -> [UploadContact] in                                    // 两个 flatMap 写的好爽，其实还可以写的更爽一些~
                        return contact.numbers.map { ["name": contact.name, "number": $0] }
                }
            }
            .asDriver(onErrorJustReturn: [])
        
        let result = request
            .flatMapLatest { rx_friendsInContacts($0) }
        
        result.asObservable()
            .flatMapLatest { result -> Observable<[DiscoveredUser]> in
                switch result {
                case .Success(let users):
                    return Observable.just(users)
                case .Failure(let error):
                    defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
                    return Observable.empty()
                }
            }
            .bindTo(elements)
            .addDisposableTo(disposeBag)
        
        [request.map { _ in true }, result.map { _ in false }]
            .toObservable()
            .merge()
            .bindTo(isLoading)
            .addDisposableTo(disposeBag)
        
    }
}
