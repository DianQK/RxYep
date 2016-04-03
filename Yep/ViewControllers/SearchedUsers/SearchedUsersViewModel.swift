//
//  SearchedUsersViewModel.swift
//  Yep
//
//  Created by 宋宋 on 16/4/3.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import RxSwift
import RxCocoa

class SearchedUsersViewModel {
    
    let isSearching = Variable(true)
    
    let searchedUser = Variable<[DiscoveredUser]>([])
    
    let notFoundUsers = Variable(false)
    
    private let disposeBag = DisposeBag()
    
    init(searchText: String) {

//        isSearched = ture
        
        let searchResult = rx_searchUsersByQ(searchText).flatMapLatest { result -> Driver<[DiscoveredUser]> in
            switch result {
            case .Success(let users):
                return Driver.just(users)
            case .Failure(let error):
                defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
                return Driver.just([])
            }
        }
        
        searchResult.asObservable()
            .bindTo(searchedUser)
            .addDisposableTo(disposeBag)
        
        searchResult.asObservable()
            .map { _ in false }
            .bindTo(isSearching)
            .addDisposableTo(disposeBag)
        
        searchResult.asObservable()
            .map { $0.isEmpty }
            .bindTo(notFoundUsers)
            .addDisposableTo(disposeBag)
        
    }
    
}
