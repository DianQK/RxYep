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
import RealmSwift

enum DiscoverUserMode: Int {
    case Normal = 0
    case Card
}

var skillSizeCache = [String: CGRect]()

class DiscoverViewModel {
    /// 当前用户选择的浏览模式
    let userMode = Variable(DiscoverUserMode.Card)
    /// 当前排序状态
    let discoveredUserSortStyle = Variable(DiscoveredUserSortStyle.Default)
    /// 当前已加载的页数
    let currentPageIndex = Variable(1)
    /// 所有的 User ，也就是最终的结果
    let discoveredUsers = Variable([DiscoveredUser]())
    /// 过滤种类（其实这个目前是死的哈）
    let filterStyles: Variable<[DiscoveredUserSortStyle]> = Variable([.Distance, .LastSignIn, .Default])
    /// 过滤状态
    let filterItems: Variable<[RxActionSheetView.Item]> = Variable([])
    /// 加载状态（还没有数据的）
    let isFetching = Variable(false)
    /// 刷新状态（下拉）
    let isRefreshing = Variable(false)
    /// 加载更多状态
    let isLoading = Variable(false)
    /// 每次加载 User 数
    private let perPage = 21
    
    private let disposeBag = DisposeBag()
    
    init(input: (refreshTriger: Driver<Void>, loadMoreTriger: Driver<Void>, filterStyleChanged: Driver<(RxActionSheetView.Item, Int)>, modeChanged: Driver<Void>)) {
        /// 尝试恢复保存的排序姿势
        if let value = YepUserDefaults.discoveredUserSortStyle.value,
            _discoveredUserSortStyle = DiscoveredUserSortStyle(rawValue: value) {
            discoveredUserSortStyle.value = _discoveredUserSortStyle
        }
        
        if let realm = try? Realm(), offlineJSON = OfflineJSON.withName(.DiscoveredUsers, inRealm: realm) {
            if let JSON = offlineJSON.JSON, discoveredUsers = parseDiscoveredUsers(JSON) {
                self.discoveredUsers.value = discoveredUsers
                self.isFetching.value = false
            }
        }
        /// 刷新请求
        let refreshRequest = input.refreshTriger.asDriver()
            .withLatestFrom(discoveredUserSortStyle.asDriver())
        
        /// 刷新结果
       let refreshResult = refreshRequest.flatMapLatest { rx_discoverUsers(masterSkillIDs: [], learningSkillIDs: [], discoveredUserSortStyle: $0, inPage: 1, withPerPage: self.perPage) }
        
        /// 切换显示方式
        input.modeChanged
            .driveNext { [unowned self] in
                switch self.userMode.value {
                case .Card: self.userMode.value = .Normal
                case .Normal: self.userMode.value = .Card
                }
            }
            .addDisposableTo(disposeBag)
        
        /// 切换显示方式后的结果
        let filterStyleChangedResult = discoveredUserSortStyle.asDriver().flatMapLatest { rx_discoverUsers(masterSkillIDs: [], learningSkillIDs: [], discoveredUserSortStyle: $0, inPage: 1, withPerPage: self.perPage) }
        
        /// 切换过滤条件要清除数据
        input.filterStyleChanged
            .driveNext { [unowned self] _ in
                self.discoveredUsers.value = []
            }
            .addDisposableTo(disposeBag)
        
        // 处理数据，当前 Index 和 Users
        [refreshResult, filterStyleChangedResult].toObservable().merge().subscribeNext { [unowned self] result in
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
        
        // 刷新状态的处理，绑定到 isFetching
        [refreshRequest.map { _ in true }, refreshResult.map { _ in false }]
            .toObservable()
            .merge()
            .bindTo(isRefreshing)
            .addDisposableTo(disposeBag)
        
        // fetch 状态的处理，绑定到 isFetching
        [input.filterStyleChanged.map { _ in true }, filterStyleChangedResult.map { _ in false }]
            .toObservable()
            .merge()
            .bindTo(isFetching)
            .addDisposableTo(disposeBag)
        
        /// 将排序状态绑定到 filterItems
        discoveredUserSortStyle.asObservable()
            .observeOn(.Serial(.Background))
            .withLatestFrom(filterStyles.asObservable()) { (current, styles) -> [RxActionSheetView.Item] in
                return styles.map { RxActionSheetView.Item.Check(title: $0.name, titleColor: UIColor.yepTintColor(), checked: $0 == current) }
            }
            .map { $0 + [.Cancel] } // 添加一个 Cancel
            .observeOn(.Main)
            .bindTo(filterItems)
            .addDisposableTo(disposeBag)
        
        /// 绑定过滤状态
        input.filterStyleChanged.asObservable()
            .withLatestFrom(filterStyles.asObservable()) {  $1[$0.1] }
            .bindTo(discoveredUserSortStyle)
            .addDisposableTo(disposeBag)
        
    }
    
}