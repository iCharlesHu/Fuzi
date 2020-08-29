// Node.swift
// Copyright (c) 2015 Ce Zheng
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

/// Define a Swifty typealias for libxml's node type enum
public typealias XMLNodeType = xmlElementType

// MARK: - Give a Swifty name to each enum case of XMLNodeType
extension XMLNodeType {
    /// Element
    public static var Element: xmlElementType       { return XML_ELEMENT_NODE }
    /// Attribute
    public static var Attribute: xmlElementType     { return XML_ATTRIBUTE_NODE }
    /// Text
    public static var Text: xmlElementType          { return XML_TEXT_NODE }
    /// CData Section
    public static var CDataSection: xmlElementType  { return XML_CDATA_SECTION_NODE }
    /// Entity Reference
    public static var EntityRef: xmlElementType     { return XML_ENTITY_REF_NODE }
    /// Entity
    public static var Entity: xmlElementType        { return XML_ENTITY_NODE }
    /// Pi
    public static var Pi: xmlElementType            { return XML_PI_NODE }
    /// Comment
    public static var Comment: xmlElementType       { return XML_COMMENT_NODE }
    /// Document
    public static var Document: xmlElementType      { return XML_DOCUMENT_NODE }
    /// Document Type
    public static var DocumentType: xmlElementType  { return XML_DOCUMENT_TYPE_NODE }
    /// Document Fragment
    public static var DocumentFrag: xmlElementType  { return XML_DOCUMENT_FRAG_NODE }
    /// Notation
    public static var Notation: xmlElementType      { return XML_NOTATION_NODE }
    /// HTML Document
    public static var HtmlDocument: xmlElementType  { return XML_HTML_DOCUMENT_NODE }
    /// DTD
    public static var DTD: xmlElementType           { return XML_DTD_NODE }
    /// Element Declaration
    public static var ElementDecl: xmlElementType   { return XML_ELEMENT_DECL }
    /// Attribute Declaration
    public static var AttributeDecl: xmlElementType { return XML_ATTRIBUTE_DECL }
    /// Entity Declaration
    public static var EntityDecl: xmlElementType    { return XML_ENTITY_DECL }
    /// Namespace Declaration
    public static var NamespaceDecl: xmlElementType { return XML_NAMESPACE_DECL }
    /// XInclude Start
    public static var XIncludeStart: xmlElementType { return XML_XINCLUDE_START }
    /// XInclude End
    public static var XIncludeEnd: xmlElementType   { return XML_XINCLUDE_END }
    /// DocbDocument
    public static var DocbDocument: xmlElementType  { return XML_DOCB_DOCUMENT_NODE }
}

infix operator ~=
/**
 For supporting pattern matching of those enum case alias getters for XMLNodeType
 
 - parameter lhs: left hand side
 - parameter rhs: right hand side
 
 - returns: true if both sides equals
 */
public func ~=(lhs: XMLNodeType, rhs: XMLNodeType) -> Bool {
    return lhs.rawValue == rhs.rawValue
}

/// Base class for all XML nodes
open class XMLNode {
    /// The document containing the element.
    public unowned let document: XMLDocument
    
    /// Whether this node is removed from parent. If `true`, the underlying cNode will be freed upon deinit
    var unlinked: Bool = false
    
    /// The type of the XMLNode
    open var type: XMLNodeType {
        return cNode.pointee.type
    }
    
    // MARK: - Accessing Parent and Sibling Elements
    /// The element's parent element.
    @LazyOptional({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode else {
            return nil
        }
        return XMLElement(cNode: node.cNode.pointee.parent, document: node.document)
    })
    public internal(set) var parent: XMLElement?
    
    /// The element's previous sibling.
    @LazyOptional({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode else {
            return nil
        }
        return XMLElement(cNode: node.cNode.pointee.prev, document: node.document)
    })
    public internal(set) var previousSibling: XMLElement?
    
    /// The element's next sibling.
    @LazyOptional({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode else {
            return nil
        }
        return XMLElement(cNode: node.cNode.pointee.next, document: node.document)
    })
    public internal(set) var nextSibling: XMLElement?
    
    // MARK: - Accessing Children Nodes
    /// Determine whether the current node has any child nodes
    /// - Returns: `true` if the current node has child nodes, `false` otherwise
    open func hasChildNodes() -> Bool {
        return self.cNode.pointee.next != nil
    }
    
    /// Get the element's child nodes of specified types
    /// - Parameter types: type of nodes that should be fetched (e.g. .Element, .Text, .Comment)
    /// - Returns: all child nodes of specified types
    open func childNodes(ofTypes types: [XMLNodeType] = [.Element, .Text]) -> [XMLNode] {
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
    open func firstChild() -> XMLNode? {
        let nodePtr = self.cNode.pointee.children
        if let childNode = nodePtr {
            switch childNode.pointee.type {
            case XMLNodeType.Element:
                return XMLElement(cNode: childNode, document: self.document)
            default:
                return XMLNode(cNode: childNode, document: self.document)
            }
        }
        return nil
    }
    
    // MARK: - Appending Child
    open func appendChild(_ child: XMLNode) {
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
    open func replaceChild(_ old: XMLNode, with new: XMLNode) {
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
    
    // MARK: - Accessing Contents
    /// Whether this is a HTML node
    open var isHTML: Bool {
        return UInt32(self.cNode.pointee.doc.pointee.properties) & XML_DOC_HTML.rawValue == XML_DOC_HTML.rawValue
    }
    
    /// A string representation of the element's value.
    @Lazy({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode else {
            return ""
        }
        let key = xmlNodeGetContent(node.cNode)
        let stringValue = ^-^key ?? ""
        xmlFree(key)
        return stringValue
    })
    public internal(set) var stringValue: String!
    
    /// The raw XML string of the element.
    @Lazy({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode else {
            return ""
        }
        let buffer = xmlBufferCreate()
        if node.isHTML {
            htmlNodeDump(buffer, node.cNode.pointee.doc, node.cNode)
        } else {
            xmlNodeDump(buffer, node.cNode.pointee.doc, node.cNode, 0, 0)
        }
        let dumped = ^-^xmlBufferContent(buffer) ?? ""
        xmlBufferFree(buffer)
        return dumped
    })
    public internal(set) var rawXML: String!
    
    // MARK: - Setting Contents
    open func setContent(_ newContent: String) {
        let encoded: UnsafeMutablePointer<xmlChar> = xmlEncodeEntitiesReentrant(self.document.cDocument, newContent)
        xmlNodeSetContent(self.cNode, encoded)
        xmlFree(encoded)
        // All parent's content must be invalided
        self.visitSelfAndAncestor(andPerform: { node in node.stringValue = nil })
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
    open func copy(recursive: Bool = true) -> XMLNode {
        // @see http://www.xmlsoft.org/html/libxml-tree.html#xmlCopyNode
        let flag: Int32 = recursive ? 1 : 2
        let newNode: XMLNode = self.cNode.pointee.type == XMLNodeType.Element ?
            XMLElement(cNode: xmlCopyNode(self.cNode, flag), document: self.document) :
            XMLNode(cNode: xmlCopyNode(self.cNode, flag), document: self.document)
        // Copy doesn't set doc correctly... set it here
        newNode.cNode.pointee.doc = self.cNode.pointee.doc
        return newNode
    }
    
    /// Convert this node to XMLElement if it is an element node
    open func toElement() -> XMLElement? {
        return self as? XMLElement
    }
    
    internal var cNode: xmlNodePtr
    
    internal init(cNode: xmlNodePtr, document: XMLDocument) {
        self.cNode = cNode
        self.document = document
        self.bindProperties()
    }
    
    internal convenience init?(cNode: xmlNodePtr?, document: XMLDocument) {
        guard let cNode = cNode else {
            return nil
        }
        self.init(cNode: cNode, document: document)
    }
    
    // MARK: - Bind Properties
    internal func bindProperties() {
        let allProperties: [Mirror.Child] = Mirror(reflecting: self).allChildren()
        for child: Mirror.Child in allProperties {
            if let wrapped: WrappedProperty = child.value as? WrappedProperty {
                wrapped.owner = self
            }
        }
    }
    
    // MARK: - Visit Ancestors
    internal func visitSelfAndAncestor(andPerform perform: (XMLNode) -> Void) {
        var currentNode: XMLNode? = self
        while let current: XMLNode = currentNode {
            perform(current)
            currentNode = current.parent
        }
    }
}

extension XMLNode: Equatable {}

/**
 Determine whether two nodes are the same
 
 - parameter lhs: XMLNode on the left
 - parameter rhs: XMLNode on the right
 
 - returns: whether lhs and rhs are equal
 */
public func ==(lhs: XMLNode, rhs: XMLNode) -> Bool {
    return lhs.cNode == rhs.cNode
}
