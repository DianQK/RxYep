//
//  YepHelpers.swift
//  Yep
//
//  Created by nixzhu on 15/11/2.
//  Copyright © 2015年 Catch Inc. All rights reserved.
//

import Foundation

final class Box<T> {
    let value: T

    init(_ value: T) {
        self.value = value
    }
}

final class HashBox<T: Hashable> {
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
}

final class OptionalBox<T> {
    let value: T?
    
    init(_ value: T?) {
        self.value = value
    }
    
}

final class OptionalHashBox<T: Hashable> {
    let value: T?
    
    init(_ value: T?) {
        self.value = value
    }
    
}

extension HashBox: Hashable {
    var hashValue: Int {
        return value.hashValue
    }
}

func ==<T>(lhs: HashBox<T>, rhs: HashBox<T>) -> Bool {
    return lhs.value == rhs.value
}

extension OptionalHashBox: Hashable {
    var hashValue: Int {
        return value?.hashValue ?? 0
    }
}

func ==<T>(lhs: OptionalHashBox<T>, rhs: OptionalHashBox<T>) -> Bool {
    return lhs.value == rhs.value
}