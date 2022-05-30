//
//  FileOperationsTests.swift
//  
//
//  Created by Manuel M T Chakravarty on 27/05/2022.
//

import XCTest
import OrderedCollections

@testable import Files
import _FilesTestSupport


class FileAddTests: XCTestCase {

  func testAddToEmpty() throws {

    let payload                              = Payload(text: "main = print 42"),
        tree: OrderedDictionary<String, Any> = ["Main.hs": payload]

    var files = Folder<Payload>(children: [:])
    files.add(item: FileOrFolder(file: File(contents: payload)), withPreferredName: "Main.hs", at: 10)
      // NB: Also tests that we handle out of range indices.

    guard let treeFiles = try? FileOrFolder(folder: Folder<Payload>(tree: tree))
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(treeFiles.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }

  func testAddInbetween() throws {

    let payload                                    = Payload(text: "main = print 42"),
        treeBefore: OrderedDictionary<String, Any> = ["C.hs": payload, "A.hs": payload],
        treeAfter: OrderedDictionary<String, Any>  = ["C.hs": payload, "B.hs": payload, "A.hs": payload]

    guard var files = try? Folder<Payload>(tree: treeBefore)
    else { XCTFail("Couldn't initialise"); return }
    files.add(item: FileOrFolder(file: File(contents: payload)), withPreferredName: "B.hs", at: 1)

    guard let treeAfterFiles = try? FileOrFolder(folder: Folder<Payload>(tree: treeAfter))
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(treeAfterFiles.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }

  func testAddAlphabet() throws {

    let payload                                    = Payload(text: "main = print 42"),
        treeBefore: OrderedDictionary<String, Any> = ["A.hs": payload, "C.hs": payload],
        treeAfter: OrderedDictionary<String, Any>  = ["A.hs": payload, "B.hs": payload, "C.hs": payload]

    guard var files = try? Folder<Payload>(tree: treeBefore)
    else { XCTFail("Couldn't initialise"); return }
    files.add(item: FileOrFolder(file: File(contents: payload)), withPreferredName: "B.hs")

    guard let treeAfterFiles = try? FileOrFolder(folder: Folder<Payload>(tree: treeAfter))
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(treeAfterFiles.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }

  func testAddCollision() throws {

    let payload                                    = Payload(text: "main = print 42"),
        treeBefore: OrderedDictionary<String, Any> = ["A.hs": payload, "B.hs": payload],
        treeAfter: OrderedDictionary<String, Any>  = ["A.hs": payload, "B.hs": payload, "B1.hs": payload]

    guard var files = try? Folder<Payload>(tree: treeBefore)
    else { XCTFail("Couldn't initialise"); return }
    files.add(item: FileOrFolder(file: File(contents: payload)), withPreferredName: "B.hs")

    guard let treeAfterFiles = try? FileOrFolder(folder: Folder<Payload>(tree: treeAfter))
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(treeAfterFiles.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }

  func testRenameSame() throws {

    let payload                               = Payload(text: "main = print 42"),
        tree: OrderedDictionary<String, Any>  = ["A.hs": payload, "B.hs": payload, "C.hs": payload]

    guard let filesTree = try? FileOrFolder(folder: Folder<Payload>(tree: tree))
    else { XCTFail("Couldn't initialise"); return }
    guard case var .folder(files) = filesTree
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(files.rename(name: "B.hs", to: "B.hs", dontMove: true), "Renaming failed")
    XCTAssert(filesTree.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }

  func testRenameDontMove() throws {

    let payload1                                    = Payload(text: "main = print 42"),
        payload2                                    = Payload(text: "main = print ?"),
        treeBefore: OrderedDictionary<String, Any>  = ["A.hs": payload1, "B.hs": payload2, "C.hs": payload1],
        treeAfter:  OrderedDictionary<String, Any>  = ["A.hs": payload1, "D.hs": payload2, "C.hs": payload1]

    guard var files = try? Folder<Payload>(tree: treeBefore)
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(files.rename(name: "B.hs", to: "D.hs", dontMove: true), "Renaming failed")

    guard let treeAfterFiles = try? FileOrFolder(folder: Folder<Payload>(tree: treeAfter))
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(treeAfterFiles.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }

  func testRenameMove() throws {

    let payload1                                    = Payload(text: "main = print 42"),
        payload2                                    = Payload(text: "main = print ?"),
        treeBefore: OrderedDictionary<String, Any>  = ["A.hs": payload1, "B.hs": payload2, "C.hs": payload1],
        treeAfter:  OrderedDictionary<String, Any>  = ["A.hs": payload1, "C.hs": payload1, "D.hs": payload2]

    guard var files = try? Folder<Payload>(tree: treeBefore)
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(files.rename(name: "B.hs", to: "D.hs", dontMove: false), "Renaming failed")

    guard let treeAfterFiles = try? FileOrFolder(folder: Folder<Payload>(tree: treeAfter))
    else { XCTFail("Couldn't initialise"); return }
    XCTAssert(treeAfterFiles.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }

  func testRenameClash() throws {

    let payload                               = Payload(text: "main = print 42"),
        tree: OrderedDictionary<String, Any>  = ["A.hs": payload, "B.hs": payload, "C.hs": payload]

    guard let filesTree = try? FileOrFolder(folder: Folder<Payload>(tree: tree))
    else { XCTFail("Couldn't initialise"); return }
    guard case var .folder(files) = filesTree
    else { XCTFail("Couldn't initialise"); return }
    XCTAssertFalse(files.rename(name: "B.hs", to: "C.hs"), "Renaming incorrectly succeded")
    XCTAssert(filesTree.sameContents(fileOrFolder: FileOrFolder(folder: files)), "Contents doesn't match")
  }
}
