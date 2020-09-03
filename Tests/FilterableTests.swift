//
//  FilterableTests.swift
//  FuziTests
//
//  Created by Charles Hu on 8/20/20.
//  Copyright © 2020 Charles Hu. All rights reserved.
//

import XCTest
@testable import Fuzi

class FilterableTests : XCTestCase {
    var document: HTMLDocument!
    
    override func setUp() {
        super.setUp()
        let filePath: URL = Bundle(for: FilterableTests.self).url(forResource: "filterable", withExtension: "html")!
        do {
            self.document = try HTMLDocument(data: Data(contentsOf: filePath))
        } catch {
            XCTAssertFalse(true, "Error happend during test initialization")
        }
    }
    
    func testGetElementById() {
        let conclusion: Fuzi.XMLElement? = self.document.getElementById("conclusion")
        XCTAssertNotNil(conclusion)
        XCTAssert(conclusion?.stringValue == "Conclusion", "getElementById found the wrong element")
    }
    
    func testGetElementsByClassName() {
        let splashes: [Fuzi.XMLElement] = self.document.getElementsByClassName("splash")
        XCTAssert(splashes.count == 11, "getElementsByClassNames found incorrect number of elements")
    }
    
    func testGetElementsByTagName() {
        let metas: [Fuzi.XMLElement] = self.document.getElementsByTagName("meta")
        XCTAssert(metas.count == 13, "getElementsByTagName found incorrect number of elements")
    }
    
    func testGetElementsByTagNames() {
        let metaAndLinks: [Fuzi.XMLElement] = self.document.getElementsByTagNames(["meta", "link"])
        XCTAssert(metaAndLinks.count == 17, "getElementsByTagNames found incorrect number of elements")
    }
}
