//
//  DiscoverViewModel.swift
//  Yep
//
//  Created by 宋宋 on 16/3/31.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import RealmSwift
import RxDataSources

typealias DiscoverSectionModel = AnimatableSectionModel<String, DiscoveredUser>

enum DiscoverUserMode: Int {
    case Normal = 0
    case Card
}

var skillSizeCache = [String: CGRect]()

class DiscoverViewModel {
    
    let userMode = Variable(DiscoverUserMode.Card)
    
    let discoveredUserSortStyle = Variable(DiscoveredUserSortStyle.Default)
    
    let currentPageIndex = Variable(1)
    
    let discoveredUsers = Variable([DiscoveredUser]())
    
    let filterStyles: Variable<[DiscoveredUserSortStyle]> = Variable([.Distance, .LastSignIn, .Default])
    
    let isFetching = Variable(false)
    
    private let perPage = 21
    
    private let disposeBag = DisposeBag()
    
    init(input: (refreshTriger: Driver<Void>, loadMoreTriger: Driver<Void>, modeChanged: Driver<Void>)) {
        
        let refreshRequest = input.refreshTriger.asDriver()
            .withLatestFrom(discoveredUserSortStyle.asDriver())
//            .withLatestFrom(currentPageIndex.asDriver()) { ($0, $1) }
        
       let refreshResult = refreshRequest
            .flatMapLatest { rx_discoverUsers(masterSkillIDs: [], learningSkillIDs: [], discoveredUserSortStyle: $0, inPage: 1, withPerPage: self.perPage) }
        // 处理数据
        refreshResult.driveNext { [unowned self] result in
            switch result {
            case .Success(let data):
                self.discoveredUsers.value = data
                self.currentPageIndex.value = 1
            case .Failure(let error):
                defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
            }
        }.addDisposableTo(disposeBag)
        // 缓存高度
        refreshResult.asObservable()
            .observeOn(.Serial(.Background))
            .subscribeNext { result in
            if case let .Success(discoveredUsers) = result {
                for user in discoveredUsers {
                    for skill in user.masterSkills {
                        let skillLocalName = skill.localName ?? ""
                        let skillID =  skill.id
                        
                        if let _ = skillSizeCache[skillID] {
                            
                        } else {
                            let rect = skillLocalName.boundingRectWithSize(CGSize(width: CGFloat(FLT_MAX), height: SkillCell.height), options: [.UsesLineFragmentOrigin, .UsesFontLeading], attributes: skillTextAttributes, context: nil)
                            
                            skillSizeCache[skillID] = rect
                        }
                    }
                }
            }
        }.addDisposableTo(disposeBag)
        // 请求状态的处理
        [refreshRequest.map { _ in true}, refreshResult.map { _ in false }]
            .toObservable()
            .merge()
            .bindTo(isFetching)
            .addDisposableTo(disposeBag)
    }
    
}