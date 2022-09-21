//
//  FilesTests.swift
//  
//
//  Created by Manuel M T Chakravarty on 06/05/2022.
//

import XCTest
import OrderedCollections

@testable import Files
import _FilesTestSupport


class FilesTests: XCTestCase {

  func testTreeTextInit() throws {

    let payload                              = Payload(text: "main = print 42"),
        tree: OrderedDictionary<String, Any> = ["Main.hs": payload]

    let treeFiles = try XCTUnwrap(try? FileOrFolder(folder: FullFolder<Payload>(tree: tree)))
    let files = FullFolder<Payload>(children: ["Main.hs" : FileOrFolder(file: File(contents: payload))])
    XCTAssert(treeFiles.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }
}
