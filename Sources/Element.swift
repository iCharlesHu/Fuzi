// Element.swift
// Copyright (c) 2015 Ce Zheng
// Copyright (c) 2020 Charles Hu
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import libxml2

/// Represents an element in `XMLDocument` or `HTMLDocument`
open class XMLElement: XMLNode {
    
    /// Whether this node is removed from parent. If `true`, the underlying cNode will be freed upon deinit
    private var unlinked: Bool = false
    
    deinit {
        if self.unlinked {
            xmlFreeNode(self.cNode)
        }
    }
    
    /// The element's namespace.
    @LazyOptional({ weakSelf in
        guard let element: XMLElement = weakSelf as? XMLElement else {
            return nil
        }
        return ^-^(element.cNode.pointee.ns != nil ?element.cNode.pointee.ns.pointee.prefix :nil)
    })
    public internal(set) var namespace: String?
    
    /// The element's tag.
    @LazyOptional({ weakSelf in
        guard let element: XMLElement = weakSelf as? XMLElement else {
            return nil
        }
        return ^-^element.cNode.pointee.name
    })
    public internal(set) var tag: String?
    
    open var text: String {
        return self.stringValue
    }
    
    // MARK: - Accessing Attributes
    /// All attributes for the element.
    @Lazy({ weakSelf in
        guard let element: XMLElement = weakSelf as? XMLElement else {
            return [:]
        }
        var attributes = [String: String]()
        var attribute = element.cNode.pointee.properties
        while attribute != nil {
            if let key = ^-^attribute?.pointee.name, let value = element.attr(key) {
                attributes[key] = value
            }
            attribute = attribute?.pointee.next
        }
        return attributes
    })
    public internal(set) var attributes: [String : String]!
    
    /**
     Returns the value for the attribute with the specified key.
     
     - parameter name: The attribute name.
     - parameter ns:   The namespace, or `nil` by default if not using a namespace
     
     - returns: The attribute value, or `nil` if the attribute is not defined.
     */
    open func attr(_ name: String, namespace ns: String? = nil) -> String? {
        var value: String? = nil
        
        let xmlValue: UnsafeMutablePointer<xmlChar>?
        if let ns = ns {
            xmlValue = xmlGetNsProp(cNode, name, ns)
        } else {
            xmlValue = xmlGetProp(cNode, name)
        }
        
        if let xmlValue = xmlValue {
            value = ^-^xmlValue
            xmlFree(xmlValue)
        }
        return value
    }
    
    // MARK: - Updating Attributes
    
    /// Update the attribute with the given name on the element and create a new attribute if no attribute exists
    /// - Parameters:
    ///   - name: the name of the attribute to update/create
    ///   - value: the value of the attribute to update/create
    open func setAttribute(_ name: String, withValue value: String) {
        xmlSetProp(self.cNode, name, value)
        self.attributes = nil // We need to clear out the cached value
    }
    
    /// Remove an attribute from the element
    /// - Parameter name: the name of the attribute to remove
    open func removeAttribute(_ name: String) {
        xmlUnsetProp(self.cNode, name)
        self.attributes = nil // We need to clear out the cached value
    }
    
    // MARK: - Accessing Children
    
    /// The element's children elements.
    open var children: [XMLElement] {
        return LinkedCNodes(head: cNode.pointee.children).compactMap {
            XMLElement(cNode: $0, document: self.document)
        }
    }
    
    /**
     Get the element's child nodes of specified types
     
     - parameter types: type of nodes that should be fetched (e.g. .Element, .Text, .Comment)
     
     - returns: all children of specified types
     */
    open func childNodes(ofTypes types: [XMLNodeType]) -> [XMLNode] {
        return LinkedCNodes(head: cNode.pointee.children, types: types).compactMap { node in
            switch node.pointee.type {
            case XMLNodeType.Element:
                return XMLElement(cNode: node, document: self.document)
            default:
                return XMLNode(cNode: node, document: self.document)
            }
        }
    }
    
    /// Returns the first child element
    /// - Returns: The child element.
    open func firstChild() -> XMLElement? {
        let nodePtr = self.cNode.pointee.children
        if let childNode = nodePtr {
            return XMLElement(cNode: childNode, document: self.document)
        }
        return nil
    }
    
    /**
     Returns the first child element with a tag, or `nil` if no such element exists.
     
     - parameter tag: The tag name.
     - parameter ns:  The namespace, or `nil` by default if not using a namespace
     
     - returns: The child element.
     */
    open func firstChild(tag: XMLCharsComparable, inNamespace ns: XMLCharsComparable? = nil) -> XMLElement? {
        var nodePtr = cNode.pointee.children
        while let cNode = nodePtr {
            if cXMLNode(nodePtr, matchesTag: tag, inNamespace: ns) {
                return XMLElement(cNode: cNode, document: self.document)
            }
            nodePtr = cNode.pointee.next
        }
        return nil
    }
    
    /// faster version of firstChild with string literals (explicitly typed as StaticString)
    open func firstChild(staticTag tag: StaticString, inNamespace ns: StaticString? = nil) -> XMLElement? {
        return firstChild(tag: tag, inNamespace: ns)
    }
    
    /**
     Returns all children elements with the specified tag.
     
     - parameter tag: The tag name.
     - parameter ns:  The namepsace, or `nil` by default if not using a namespace
     
     - returns: The children elements.
     */
    open func children(tag: XMLCharsComparable, inNamespace ns: XMLCharsComparable? = nil) -> [XMLElement] {
        return LinkedCNodes(head: cNode.pointee.children).compactMap {
            cXMLNode($0, matchesTag: tag, inNamespace: ns)
                ? XMLElement(cNode: $0, document: self.document) : nil
        }
    }
    
    /// faster version of children with string literals (explicitly typed as StaticString)
    open func children(staticTag tag: StaticString, inNamespace ns: StaticString? = nil) -> [XMLElement] {
        return children(tag: tag, inNamespace: ns)
    }
    
    /// Returns the current number of children elements.
    /// - Returns: the number of children elements of this node.
    open func numberOfChildren() -> Int {
        return Int(xmlChildElementCount(self.cNode))
    }
    
    // MARK: - Appending Child
    open func appendChild(_ child: XMLElement) {
        xmlAddChild(self.cNode, child.cNode)
        child.unlinked = false
        // Update relationships
        child.nextSibling = nil
        child.previousSibling = nil
        child.parent = nil
        self.visitSelfAndAncestor(andPerform: { node in
            node.rawXML = nil
            node.stringValue = nil
        })
    }
    
    // MARK: - Replacing Child
    /// Replace the child with a new element
    /// - Parameters:
    ///   - old: the child to be replaced
    ///   - new: the element to replace the child with
    open func replaceChild(_ old: XMLElement, with new: XMLElement) {
        xmlReplaceNode(old.cNode, new.cNode)
        old.unlinked = true
        new.unlinked = false
        // Reset all lazy properties regarding siblings and parents
        old.parent = nil
        old.previousSibling = nil
        old.nextSibling = nil
        new.parent = nil
        new.previousSibling = nil
        new.nextSibling = nil
        self.visitSelfAndAncestor(andPerform: { node in
            node.stringValue = nil
            node.rawXML = nil
        })
    }
    
    // MARK: - Accessing Content
    /// Whether the element has a value.
    open var isBlank: Bool {
        return stringValue.isEmpty
    }
    
    /// A number representation of the element's value, which is generated from the document's `numberFormatter` property.
    open fileprivate(set) lazy var numberValue: NSNumber? = {
        return self.document.numberFormatter.number(from: self.stringValue)
    }()
    
    /// A date representation of the element's value, which is generated from the document's `dateFormatter` property.
    open fileprivate(set) lazy var dateValue: Date? = {
        return self.document.dateFormatter.date(from: self.stringValue)
    }()
    
    // MARK: - Setting Content
    open func setText(_ newText: String) {
        self.setContent(newText)
    }
    
    /**
     Returns the child element at the specified index.
     
     - parameter idx: The index.
     
     - returns: The child element.
     */
    open subscript (idx: Int) -> XMLElement? {
        return children[idx]
    }
    
    /**
     Returns the value for the attribute with the specified key.
     
     - parameter name: The attribute name.
     
     - returns: The attribute value, or `nil` if the attribute is not defined.
     */
    open subscript (name: String) -> String? {
        return attr(name)
    }
    
    // MARK: - Remove Self
    open func remove() {
        xmlUnlinkNode(self.cNode)
        self.unlinked = true
        // All parent's text and html needs to be reset
        self.parent = nil
        self.nextSibling = nil
        self.previousSibling = nil
        self.visitSelfAndAncestor { (node) in
            node.stringValue = nil
            node.rawXML = nil
        }
    }
    
    // MARK: - Copy Self
    open func copy(recursive: Bool = true) -> XMLElement {
        // @see http://www.xmlsoft.org/html/libxml-tree.html#xmlCopyNode
        let flag: Int32 = recursive ? 1 : 2
        let newNode: XMLElement = XMLElement(cNode: xmlCopyNode(self.cNode, flag), document: self.document)
        // Copy doesn't set doc correctly... set it here
        newNode.cNode.pointee.doc = self.cNode.pointee.doc
        return newNode
    }
    
    // MARK: - Recusively Visit Nodes
    open func visit(_ perform: ((XMLElement) -> Bool)) {
        self.visit(perform, on: self)
    }
    
    private func visit(_ perform: ((XMLElement) -> Bool), on element: XMLElement) {
        let shouldContinue: Bool = perform(element)
        guard shouldContinue else {
            return
        }
        for child: XMLElement in element.children {
            self.visit(perform, on: child)
        }
    }
    
    // MARK: - Get / Set HTML
    open var html: String {
        return self.rawXML
    }
    
    /// Replace the current element's HTML with the given one. This method parses the new HTML to construct the new node
    /// - Parameter html: the new HTML string to replace
    /// - Throws: `XMLError.invalidData` if the new HTML string is invalid
    open func setHTML(_ html: String) throws {
        // First we need to create a new document based on the html string
        let newDoc: xmlDocPtr? = xmlReadMemory(html, Int32(html.count), nil, nil, 0)
        guard newDoc != nil else {
            throw XMLError.invalidData
        }
        let newNode: xmlNodePtr? = xmlDocCopyNode(xmlDocGetRootElement(newDoc), self.document.cDocument, 1)
        guard newNode != nil else {
            throw XMLError.invalidData
        }
        // Now we need to replace self with the new node
        self.parent?.replaceChild(self, with: XMLElement(cNode: newNode!, document: self.document))
        // Update the Element itself to the new node
        xmlFreeNode(self.cNode)
        self.cNode = newNode!
        self.unlinked = false
        // Setting the HTML on self means all parent's HTML dump and text dump are now invalid
        self.tag = nil
        self.namespace = nil
        self.attributes = nil
        self.visitSelfAndAncestor(andPerform: { node in
            node.rawXML = nil
            node.stringValue = nil
        })
    }
}
