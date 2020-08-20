//
//  Filterable.swift
//  Fuzi
//
//  Created by Charles Hu on 8/20/20.
//  Copyright © 2020 Charles Hu. All rights reserved.
//

import Foundation
import libxml2

/// The `Filterable` protocol is adopted by `XMLDocument`, and `XMLElement` denoting that they can filter elements
/// by `class`, `id`, and `tag`
public protocol Filterable {
    /// Returns a list of `XMLElement` which contains every descendant element which has the specified class name or names.
    /// @see
    /// - Parameter className: the class name to filter. If multiple class names is supplied, separate them by a space.
    /// - Returns: the list of `XMLElement`s found.
    func getElementsByClassName(_ className: String) -> [XMLElement]
    /// Returns an `XMLElement` object representing the element whose id property matches the specified string.
    /// - Parameter id: the id of the element to filter
    /// - Returns: the `XMLElement` found, or `nil` if no element found
    func getElementById(_ id: String) -> XMLElement?
    /// Returns a list of `XMLElement`s containing all descendant elements, of a particular tag name, from the current element.
    /// - Parameter tag: the tag name to filter
    /// - Returns: the list of `XMLElement`s found
    func getElementsByTagName(_ tag: String) -> [XMLElement]
}

extension XMLElement : Filterable {
    public func getElementsByClassName(_ className: String) -> [XMLElement] {
        var result: [XMLElement] = []
        let searchSet: Set<String> = Set(className.split(separator: " ").map({substring in String(substring)}))
        self.visit { (element: XMLElement) -> Bool in
            if let classNames: String = element.attr("class") {
                let classNamesSet: Set<String> = Set(classNames.split(separator: " ").map({substring in String(substring)}))
                if classNamesSet.isSuperset(of: searchSet) {
                    result.append(element)
                }
            }
            return true
        }
        return result
    }
    
    public func getElementById(_ id: String) -> XMLElement? {
        var result: XMLElement? = nil
        self.visit { (element: XMLElement) -> Bool in
            if let idValue: String = element.attr("id"), id == idValue {
                result = element
                return false
            }
            return true
        }
        return result
    }
    
    public func getElementsByTagName(_ tag: String) -> [XMLElement] {
        var result: [XMLElement] = []
        self.visit { (element: XMLElement) -> Bool in
            if let currentTag: String = element.tag, currentTag == tag {
                result.append(element)
            }
            return true
        }
        return result
    }
}

extension XMLDocument : Filterable {
    public func getElementsByClassName(_ className: String) -> [XMLElement] {
        return self.root?.getElementsByClassName(className) ?? []
    }
    
    public func getElementById(_ id: String) -> XMLElement? {
        return self.root?.getElementById(id)
    }
    
    public func getElementsByTagName(_ tag: String) -> [XMLElement] {
        return self.root?.getElementsByTagName(tag) ?? []
    }
}
