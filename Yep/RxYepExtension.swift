//
//  RxYepExtension.swift
//  Yep
//
//  Created by 宋宋 on 16/4/1.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import RxSwift
import RxCocoa

extension UITableView {
    
    public func rx_modelItemSelected<T>(modelType: T.Type) -> ControlEvent<(tableView: UITableView, model: T, item: NSIndexPath)> {
        let source: Observable<(tableView: UITableView, model: T, item: NSIndexPath)> = rx_itemSelected.flatMap { [weak self] indexPath -> Observable<(tableView: UITableView, model: T, item: NSIndexPath)> in
            guard let view = self else {
                return Observable.empty()
            }
            
            return Observable.just((tableView: view, model: try view.rx_modelAtIndexPath(indexPath), item: indexPath))
        }
        
        return ControlEvent(events: source)
    }
    
}

extension UICollectionView {
    
    public func rx_modelItemSelected<T>(modelType: T.Type) -> ControlEvent<(collectionView: UICollectionView, model: T, item: NSIndexPath)> {
        let source: Observable<(collectionView: UICollectionView, model: T, item: NSIndexPath)> = rx_itemSelected.flatMap { [weak self] indexPath -> Observable<(collectionView: UICollectionView, model: T, item: NSIndexPath)> in
            guard let view = self else {
                return Observable.empty()
            }
            
            return Observable.just((collectionView: view, model: try view.rx_modelAtIndexPath(indexPath), item: indexPath))
        }
        
        return ControlEvent(events: source)
    }
    
}

extension UIBarButtonItem {
    
    public var rx_title: AnyObserver<String?> {
        return UIBindingObserver(UIElement: self) { barButton, title in
            barButton.title = title
        }.asObserver()
    }
    
}