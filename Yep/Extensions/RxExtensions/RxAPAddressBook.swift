//
//  RxAPAddressBook.swift
//  Yep
//
//  Created by 宋宋 on 16/4/2.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import APAddressBook
import RxSwift

extension APAddressBook {
    
    func rx_loadContacts() -> Observable<[APContact]> {
        return Observable.create { observe in
            
            self.loadContacts { contacts, error in
                if let contacts = contacts {
                    observe.onNext(contacts)
                    observe.onCompleted()
                } else if let error = error {
                    observe.onError(error)
                } else {
                    observe.onCompleted()
                }
            }
            
            return NopDisposable.instance
        }
        
    }
}