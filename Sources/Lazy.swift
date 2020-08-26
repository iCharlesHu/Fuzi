//
//  Lazy.swift
//  Fuzi
//
//  Created by Charles Hu on 8/25/20.
//  Copyright © 2020 Charles Hu. All rights reserved.
//

import Foundation
import libxml2

protocol WrappedProperty : class {
    var owner: AnyObject? { get set }
}

@propertyWrapper
public final class Lazy<Value> : WrappedProperty {
    private let computeFunc: (AnyObject?) -> Value
    private var cached: Value?
    weak var owner: AnyObject?
    public var wrappedValue: Value! {
        get {
            if self.cached == nil {
                self.cached = self.computeFunc(self.owner)
            }
            return self.cached
        }
        set {
            if newValue == nil {
                self.cached = nil
            }
        }
    }
    
    init(_ computeFunc: @escaping (AnyObject?) -> Value) {
        self.computeFunc = computeFunc
        self.cached = nil
    }
}

@propertyWrapper
public final class LazyOptional<Value> : WrappedProperty {
    private let computeFunc: (AnyObject?) -> Value?
    private var cleared: Bool
    private var cached: Value?
    weak var owner: AnyObject?
    public var wrappedValue: Value? {
        get {
            if self.cleared {
                self.cached = self.computeFunc(self.owner)
            }
            return self.cached
        }
        set {
            if newValue == nil {
                self.cleared = true
                self.cached = nil
            }
        }
    }
    
    init(_ computeFunc: @escaping (AnyObject?) -> Value?) {
        self.computeFunc = computeFunc
        self.cleared = true
    }
}

extension Mirror {
    func allChildren() -> [Mirror.Child] {
        var children: [Mirror.Child] = []
        for child: Mirror.Child in self.children {
            children.append(child)
        }
        if let superMirror: Mirror = self.superclassMirror {
            children += superMirror.allChildren()
        }
        return children
    }
}
