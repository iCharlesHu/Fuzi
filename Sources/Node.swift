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
    
    /// The node's previous sibling.
    @LazyOptional({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode else {
            return nil
        }
        let sibling: xmlNodePtr? = node.cNode.pointee.prev
        return sibling?.pointee.type == XMLNodeType.Element ?
            XMLElement(cNode: sibling, document: node.document) :
            XMLNode(cNode: sibling, document: node.document)
    })
    public internal(set) var previousSibling: XMLNode?
    
    /// The node's previous element sibling
    @LazyOptional({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode else {
            return nil
        }
        return XMLElement(cNode: xmlPreviousElementSibling(node.cNode), document: node.document)
    })
    public internal(set) var previousElementSibling: XMLElement?
    
    /// The node's next sibling.
    @LazyOptional({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode, node.cNode.pointee.next != nil else {
            return nil
        }
        let sibling: xmlNodePtr? = node.cNode.pointee.next
        return sibling?.pointee.type == XMLNodeType.Element ?
            XMLElement(cNode: sibling, document: node.document) :
            XMLNode(cNode: node.cNode.pointee.next, document: node.document)
    })
    public internal(set) var nextSibling: XMLNode?
    
    /// The node's next element sibling
    @LazyOptional({ weakSelf in
        guard let node: XMLNode = weakSelf as? XMLNode else {
            return nil
        }
        return XMLElement(cNode: xmlNextElementSibling(node.cNode), document: node.document)
    })
    public internal(set) var nextElementSibling: XMLElement?
    
    // MARK: - Accessing Children Nodes
    /// Determine whether the current node has any child nodes
    /// - Returns: `true` if the current node has child nodes, `false` otherwise
    open func hasChildNodes() -> Bool {
        return self.cNode.pointee.children != nil
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
    open func firstChildNode() -> XMLNode? {
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
    
    /// Returns the number of child nodes of the current node
    /// - Returns: The number of nodes that the current node has
    open func numberOfChildNodes() -> Int {
        var nodePtr: xmlNodePtr? = self.cNode.pointee.children
        var count: Int = 0
        while let node: xmlNodePtr = nodePtr {
            count += 1
            nodePtr = node.pointee.next
        }
        return count
    }
    
    /// Determine wheter the current node has child elements
    /// - Returns: `true` if the current node has child elements, or `false` otherwise.
    open func hasChildElements() -> Bool {
        var nodePtr: xmlNodePtr? = self.cNode.pointee.children
        while let node: xmlNodePtr = nodePtr {
            if node.pointee.type == XMLNodeType.Element {
                return true
            }
            nodePtr = node.pointee.next
        }
        return false
    }
    
    /// The element's children elements.
    open var children: [XMLElement] {
        return LinkedCNodes(head: cNode.pointee.children).compactMap {
            XMLElement(cNode: $0, document: self.document)
        }
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
    
    /// Returns the first child element of any tag
    /// - Returns: The first child element, or `nil` if none found.
    open func firstChildElement() -> XMLElement? {
        var nodePtr: xmlNodePtr? = self.cNode.pointee.children
        while let node: xmlNodePtr = nodePtr {
            if node.pointee.type == XMLNodeType.Element {
                return XMLElement(cNode: node, document: self.document)
            }
            nodePtr = node.pointee.next
        }
        return nil
    }
    
    /**
     Returns the first child element with a tag, or `nil` if no such element exists.
     
     - parameter tag: The tag name.
     - parameter ns:  The namespace, or `nil` by default if not using a namespace
     
     - returns: The child element.
     */
    open func firstChildElement(tag: XMLCharsComparable, inNamespace ns: XMLCharsComparable? = nil) -> XMLElement? {
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
    open func firstChildElement(staticTag tag: StaticString, inNamespace ns: StaticString? = nil) -> XMLElement? {
        return firstChildElement(tag: tag, inNamespace: ns)
    }
    
    /// Returns the current number of children elements.
    /// - Returns: the number of children elements of this node.
    open func numberOfChildElements() -> Int {
        return Int(xmlChildElementCount(self.cNode))
    }
    
    // MARK: - Appending Child
    open func appendChild(_ child: XMLNode) {
        self.visitSelfAndAncestor(andPerform: { node in
            node.rawXML = nil
            node.stringValue = nil
        })
        // Update relationships
        child.nextSibling = nil
        child.nextElementSibling = nil
        child.previousSibling = nil
        child.previousElementSibling = nil
        child.parent = nil
        // We need to free the node from the current context first before we append it to another context
        xmlUnlinkNode(child.cNode)
        xmlAddChild(self.cNode, child.cNode)
    }
    
    // MARK: - Replacing Child
    /// Replace the child with a new element
    /// - Parameters:
    ///   - old: the child to be replaced
    ///   - new: the element to replace the child with
    open func replaceChild(_ old: XMLNode, with new: XMLNode) {
        self.visitSelfAndAncestor(andPerform: { node in
            node.stringValue = nil
            node.rawXML = nil
        })
        // Reset all lazy properties regarding siblings and parents
        old.parent = nil
        old.previousSibling = nil
        old.previousElementSibling = nil
        old.nextSibling = nil
        old.nextElementSibling = nil
        new.parent = nil
        new.previousSibling = nil
        new.previousElementSibling = nil
        new.nextSibling = nil
        new.nextElementSibling = nil
        xmlReplaceNode(old.cNode, new.cNode)
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
        self.visitSelfAndAncestor { (node) in
            node.stringValue = nil
            node.rawXML = nil
        }
        // All parent's text and html needs to be reset
        self.parent = nil
        self.nextSibling = nil
        self.nextElementSibling = nil
        self.previousSibling = nil
        self.previousElementSibling = nil
        xmlUnlinkNode(self.cNode)
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
