// HTMLTests.swift
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

import XCTest
import Fuzi

class HTMLTests: XCTestCase {
    var document: HTMLDocument!
    override func setUp() {
        super.setUp()
        let filePath = Bundle(for: HTMLTests.self).url(forResource: "web", withExtension: "html")!
        do {
            document = try HTMLDocument(data: Data(contentsOf: filePath))
        } catch {
            XCTAssertFalse(true, "Error should not be thrown")
        }
    }
    
    func testRoot() {
        XCTAssertEqual(document.root!.tag, "html", "html not root element")
    }
    
    func testRootChildren() {
        let children = document.root?.children
        XCTAssertNotNil(children)
        XCTAssertEqual(children?.count, 2, "root element should have exactly two children")
        XCTAssertEqual(children?.first?.tag, "head", "head not first child of html")
        XCTAssertEqual(children?.last?.tag, "body", "body not last child of html")
    }
    
    func testTitleXPath() {
        var idx = 0
        for element in document.xpath("//head/title") {
            XCTAssertEqual(idx, 0, "more than one element found")
            XCTAssertEqual(element.stringValue, "mattt/Ono", "title mismatch")
            idx += 1
        }
        XCTAssertEqual(idx, 1, "should be exactly 1 element")
    }
    
    func testTitleCSS() {
        var idx = 0
        for element in document.css("head title") {
            XCTAssertEqual(idx, 0, "more than one element found")
            XCTAssertEqual(element.stringValue, "mattt/Ono", "title mismatch")
            idx += 1
        }
        XCTAssertEqual(idx, 1, "should be exactly 1 element")
    }
    
    func testIDCSS() {
        var idx = 0
        for element in document.css("#account_settings") {
            XCTAssertEqual(idx, 0, "more than one element found")
            XCTAssertEqual(element["href"], "/settings/profile", "href mismatch")
            idx += 1
        }
        XCTAssertEqual(idx, 1, "should be exactly 1 element")
    }
    
    func testThrowError() {
        do {
            document = try HTMLDocument(cChars: [CChar]())
            XCTAssertFalse(true, "error should have been thrown")
        } catch XMLError.parserFailure {
            
        } catch {
            XCTAssertFalse(true, "error type should be ParserFailure")
        }
    }
    
    func testTitle() {
        XCTAssertEqual(document.title, "mattt/Ono", "title is not correct")
    }
    
    func testHead() {
        let head = document.head
        XCTAssertNotNil(head)
        XCTAssertEqual(head?.children(tag: "link").count, 13, "link element count is incorrect")
        XCTAssertEqual(head?.children(tag: "meta").count, 38, "meta element count is incorrect")
        let scripts = head?.children(tag: "script")
        XCTAssertEqual(scripts?.count, 2, "scripts count is incorrect")
        XCTAssertEqual(scripts?.first?["src"], "https://github.global.ssl.fastly.net/assets/frameworks-3d18c504ea97dc018d44d64d8fce147a96a944b8.js", "script 1's src is incorrect")
        XCTAssertEqual(scripts?.last?["src"], "https://github.global.ssl.fastly.net/assets/github-602f74794536bf3e30e883a2cf268ca8e05b651d.js", "script 2's src is incorrect")
        XCTAssertEqual(head?["prefix"], "og: http://ogp.me/ns# fb: http://ogp.me/ns/fb# object: http://ogp.me/ns/object# article: http://ogp.me/ns/article# profile: http://ogp.me/ns/profile#", "prefix attribute value is incorrect")
    }
    
    func testBody() {
        let body = document.body
        XCTAssertNotNil(body)
        XCTAssertEqual(body?["class"], "logged_in  env-production macintosh vis-public", "body class is incorrect")
        XCTAssertEqual(body?.children(tag: "div").count, 4, "div count is incorrect")
    }
    
    func testChildNodesWithElementsAndTextNodes() {
        let mixedNode = document.firstChild(css: "#ajax-error-message")
        let childNodes = mixedNode?.childNodes(ofTypes: [.Element, .Text])
        XCTAssertEqual(childNodes?.count, 5, "should have 5 child nodes")
        XCTAssertEqual(childNodes?.compactMap { $0.toElement() }.count, 2, "should have 2 element nodes")
        XCTAssertEqual(childNodes?.compactMap { $0.type == .Element ? $0 : nil }.count, 2, "should have 2 element nodes")
        XCTAssertEqual(childNodes?.compactMap { $0.type == .Text ? $0 : nil }.count, 3, "should have 3 text nodes")
    }
    
    func testNextSiblingDoesNotCrash() {
        var child = document.root?.children.first
        while(child != nil) {
            child = child?.nextSibling
        }
    }
    
    func testCreateElement() {
        let newElement: Fuzi.XMLElement = self.document.createElement(withTag: "div")
        XCTAssert(newElement.tag == "div", "Newly created element doesn't have expected tag")
    }
    
    func testSetAttribute() {
        let body: Fuzi.XMLElement = self.document.body!
        XCTAssertNil(body.attr("data-test-attr"))
        body.setAttribute("data-test-attr", withValue: "DangerZone")
        XCTAssertNotNil(body.attr("data-test-attr"))
        XCTAssert(body.attr("data-test-attr") == "DangerZone", "Newly set attribute doesn't equal to the expected value")
    }
    
    func testRemoveAttribute() {
        let body: Fuzi.XMLElement = self.document.body!
        body.setAttribute("data-test-attr", withValue: "DangerZone")
        XCTAssertNotNil(body.attr("data-test-attr"))
        body.removeAttribute("data-test-attr")
        XCTAssertNil(body.attr("data-test-attr"))
    }
    
    func testNumberOfChildren() {
        let userLinks: Fuzi.XMLElement = self.document.getElementById("user-links")!
        XCTAssert(userLinks.numberOfChildren() == 4, "numberOfChildren() returns incorrect value")
    }
    
    func testAppendChild() {
        let id: String = "data-new-element"
        let body: Fuzi.XMLElement = self.document.body!
        let newElement: Fuzi.XMLElement = self.document.createElement(withTag: "div")
        newElement.setAttribute("id", withValue: id)
        XCTAssertNil(body.getElementById(id)) // Before insert body shouldn't have this element
        body.appendChild(newElement)
        XCTAssertNotNil(body.getElementById(id)) // After insert body should now have this new element
    }
    
    func testRemove() {
        let body: Fuzi.XMLElement = self.document.body!
        // Body should have readme
        XCTAssertNotNil(body.getElementById("readme"))
        let readme: Fuzi.XMLElement = body.getElementById("readme")!
        readme.remove()
        XCTAssertNil(body.getElementById("readme"))
    }
    
    func testCopy() {
        let body: Fuzi.XMLElement = self.document.body!
        let bodyCopy: Fuzi.XMLElement = body.copy()
        let readme: Fuzi.XMLElement = bodyCopy.getElementById("readme")!
        readme.remove()
        // Now the old body should still have readme whereas the new body shoudn't
        XCTAssertNotNil(body.getElementById("readme"))
        XCTAssertNil(bodyCopy.getElementById("readme"))
    }
}
