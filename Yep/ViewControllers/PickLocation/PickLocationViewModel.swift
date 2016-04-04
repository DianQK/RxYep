//
//  PickLocationViewModel.swift
//  Yep
//
//  Created by 宋宋 on 16/4/4.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import RxSwift
import RxCocoa
import MapKit
import RxMKMapView

class PickLocationViewModel {
    /// 最终结果，用 elements 可能更好理解，可以一下子知道最终我们最需要的是什么哈
    let foursquareVenues = Variable<[FoursquareVenue]>([])
    
    let searchedMapItems = Variable<[MKMapItem]>([])
    /// 中心点？
    let centerCoordinate: Driver<CLLocationCoordinate2D>
    
    private let disposeBag = DisposeBag()
    
    init(input: (didUpdateLocation: Driver<CLLocation>, searchPlacesName: Driver<String>)) {
        
        /// 将更新的位置的 coordinate ，ViewController 可能拿来用于设置中心点
        centerCoordinate = input.didUpdateLocation
            .map { $0.coordinate }

        centerCoordinate
            .map { $0.yep_cancelChinaLocationShift }
            .flatMapLatest { rx_foursquareVenuesNearby(coordinate: $0) }.flatMapLatest { result -> Driver<[FoursquareVenue]> in
                switch result {
                case .Success(let venues):
                    return Driver.just(venues)
                case .Failure(let error):
                    defaultFailureHandler(reason: error.reason, errorMessage: error.errorMessage)
                    return Driver.empty()
                }
            }
            .asObservable()
            .bindTo(foursquareVenues)
            .addDisposableTo(disposeBag)
        
        
        
        input.searchPlacesName
            .map { name -> MKLocalSearchRequest in
                let request = MKLocalSearchRequest()
                request.naturalLanguageQuery = name
                return request
            }.flatMapLatest { request -> Driver<[MKMapItem]> in
                return Observable.create { observer in // 创建一个搜索，也可以自己写一个 extension
                    let search = MKLocalSearch(request: request)
                    search.startWithCompletionHandler { response, error in // 忽略 Error 先
                        if let mapItems = response?.mapItems {
                            let searchedMapItems = mapItems.filter { $0.placemark.name != nil }
                            observer.onNext(searchedMapItems)
                            observer.onCompleted()
                        }
                    }
                    return AnonymousDisposable {
                        search.cancel()
                    }
                }
                    .asDriver(onErrorJustReturn: [])
            }
            .asObservable()
            .bindTo(searchedMapItems)
            .addDisposableTo(disposeBag)
        
        
        
        
        
    }
    
}