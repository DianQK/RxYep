//
//  ContactsViewModel.swift
//  Yep
//
//  Created by 宋宋 on 16/4/3.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import RxOptional
import RealmSwift

class ContactsViewModel {
    // TODO: - 异步加载
    let friends = Variable(normalFriends())
    
    let filteredFriends = Variable<Results<User>?>(nil) // 数据都从 realm 中拿
    
    let searchedUsers = Variable<[DiscoveredUser]>([])
    
    let noContacts = Variable(false)
    
    let searchControllerIsActive = Variable(false)
    
    let searchText = PublishSubject<String>()
    
    private var realmNotificationToken: NotificationToken?
    
    private let disposeBag = DisposeBag()
    
    init() {
        
        friends.asObservable()
            .map { $0.isEmpty }
            .bindTo(noContacts)
            .addDisposableTo(disposeBag)
        
        searchText.asDriver(onErrorJustReturn: "")
            .flatMapLatest { rx_searchUsersByQ($0) }
            .flatMapLatest { result -> Driver<[DiscoveredUser]> in
                switch result {
                case .Success(let users):
                    return Driver.just(users)
                case .Failure(let error):
                    defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
                    return Driver.empty()
                }
            }
            .asObservable()
            .bindTo(searchedUsers)
            .addDisposableTo(disposeBag)
        
        let predicate = searchText.asObservable()
//            .observeOn(.Realm) // ==
            .map { NSPredicate(format: "nickname CONTAINS[c] %@ OR username CONTAINS[c] %@", $0, $0) }
        
        Observable.combineLatest(predicate, friends.asObservable().observeOn(.Realm)) { $1.filter($0) }
            .observeOn(.Main)
            .bindTo(filteredFriends)
            .addDisposableTo(disposeBag)
        
        searchText.asDriver(onErrorJustReturn: "")
            .flatMapLatest { searchText -> Driver<RxYepResult<[DiscoveredUser]>> in
                guard searchText.isNotEmpty else { // 如果查询字段是空，立即返回一个空数据
                    return Driver.just(RxYepResult.Success([]))
                }
                return rx_searchUsersByQ(searchText)
            }
            .flatMapLatest { result -> Driver<[DiscoveredUser]> in
                switch result {
                case .Success(let users):
                    return Driver.just(users)
                case .Failure(let error):
                    defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
                    return Driver.empty()
                }
            }
            .asObservable()
//            .withLatestFrom(friends.asObservable()) { (friends: $1, users: $0) }
//            .map { (friends, users) -> [DiscoveredUser] in // 筛选不是好友的 User
//                return users.filter { user in
//                    return !friends.contains { $0.userID == user.id }
//                }
//            } // 过滤操作不应该由 ViewModel 来做，同时这里也不是过滤的最佳时机
            .bindTo(searchedUsers)
            .addDisposableTo(disposeBag)
        
    }
    
}
