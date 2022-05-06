//
//  FilesTests.swift
//  
//
//  Created by Manuel M T Chakravarty on 06/05/2022.
//

import XCTest
@testable import Files

struct Payload: FileContents {
  init(text: String) {
    self.text = text
  }

  init(name: String, data: Data) throws {
    guard let text = String(data: data, encoding: .utf8) else { throw CocoaError(.formatting) }
    self.text = text
  }

  func data() throws -> Data {
    guard let data = text.data(using: .utf8) else { throw CocoaError(.formatting) }
    return data
  }

  var text: String
}


class FilesTests: XCTestCase {

  func testTreeTextInit() throws {

    let payload = Payload(text: "main = print 42"),
        tree    = ["Main.hs": payload]

    guard let treeFiles = try? FileOrFolder(folder: Folder<Payload>(tree: tree))
    else { XCTFail("Couldn't initialise"); return }
    let files = Folder<Payload>(children: ["Main.hs" : FileOrFolder(file: File(contents: payload))])
    XCTAssert(treeFiles.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }
}
