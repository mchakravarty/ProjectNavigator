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


func performOnFolder(folder: Folder<File<Payload>, Payload>, action: (inout Folder<File<Payload>.Proxy, Payload>) -> ())
  -> FileOrFolder<File<Payload>, Payload>
{
  let fileTree = FileTree(files: FileOrFolder(folder: folder))
  if case var .folder(proxyFolder) = fileTree.root {
    action(&proxyFolder)
    fileTree.root = .folder(proxyFolder)
  }
  return try! fileTree.root.snapshot()
}

class FileAddTests: XCTestCase {

  func testAddToEmpty() throws {

    let payload                              = Payload(text: "main = print 42"),
        tree: OrderedDictionary<String, Any> = ["Main.hs": payload]

    let result = performOnFolder(folder: FullFolder<Payload>(children: [:])) { folder in
      folder.add(item: FileOrFolder(file: File(contents: payload)), withPreferredName: "Main.hs", at: 10)
      // NB: Also tests that we handle out of range indices.
    }

    let treeFiles = try FileOrFolder(folder: FullFolder<Payload>(tree: tree))
    XCTAssert(treeFiles.sameContents(fileOrFolder: result), "Contents doesn't match")
  }

  func testAddInbetween() throws {

    let payload                                    = Payload(text: "main = print 42"),
        treeBefore: OrderedDictionary<String, Any> = ["C.hs": payload, "A.hs": payload],
        treeAfter: OrderedDictionary<String, Any>  = ["C.hs": payload, "B.hs": payload, "A.hs": payload]

    let result = performOnFolder(folder: try FullFolder<Payload>(tree: treeBefore)) { folder in
      folder.add(item: FileOrFolder(file: File(contents: payload)), withPreferredName: "B.hs", at: 1)
    }

    let treeAfterFiles = try FileOrFolder(folder: FullFolder<Payload>(tree: treeAfter))
    XCTAssert(treeAfterFiles.sameContents(fileOrFolder: result), "Contents doesn't match")
  }

  func testAddAlphabet() throws {

    let payload                                    = Payload(text: "main = print 42"),
        treeBefore: OrderedDictionary<String, Any> = ["A.hs": payload, "C.hs": payload],
        treeAfter: OrderedDictionary<String, Any>  = ["A.hs": payload, "B.hs": payload, "C.hs": payload]

    let result = performOnFolder(folder: try FullFolder<Payload>(tree: treeBefore)) { folder in
      folder.add(item: FileOrFolder(file: File(contents: payload)), withPreferredName: "B.hs")
    }

    let treeAfterFiles = try FileOrFolder(folder: FullFolder<Payload>(tree: treeAfter))
    XCTAssert(treeAfterFiles.sameContents(fileOrFolder: result), "Contents doesn't match")
  }

  func testAddCollision() throws {

    let payload                                    = Payload(text: "main = print 42"),
        treeBefore: OrderedDictionary<String, Any> = ["A.hs": payload, "B.hs": payload],
        treeAfter: OrderedDictionary<String, Any>  = ["A.hs": payload, "B.hs": payload, "B1.hs": payload]

    let result = performOnFolder(folder: try FullFolder<Payload>(tree: treeBefore)) { folder in
      folder.add(item: FileOrFolder(file: File(contents: payload)), withPreferredName: "B.hs")
    }

    let treeAfterFiles = try XCTUnwrap(try? FileOrFolder(folder: FullFolder<Payload>(tree: treeAfter)))
    XCTAssert(treeAfterFiles.sameContents(fileOrFolder: result), "Contents doesn't match")
  }
}

  class FileRenameTests: XCTestCase {

    func testRenameSame() throws {

      let payload                               = Payload(text: "main = print 42"),
          tree: OrderedDictionary<String, Any>  = ["A.hs": payload, "B.hs": payload, "C.hs": payload]

      var initialFolder: Folder<File<Payload>, Payload>!
      let result = performOnFolder(folder: try FullFolder<Payload>(tree: tree)) { folder in
        initialFolder = try! folder.snapshot()
        XCTAssert(folder.rename(name: "B.hs", to: "B.hs", dontMove: true), "Renaming failed")
      }
      XCTAssert(result.sameContents(fileOrFolder: FileOrFolder(folder: initialFolder)), "Contents doesn't match")
    }

    func testRenameDontMove() throws {

      let payload1                                    = Payload(text: "main = print 42"),
          payload2                                    = Payload(text: "main = print ?"),
          treeBefore: OrderedDictionary<String, Any>  = ["A.hs": payload1, "B.hs": payload2, "C.hs": payload1],
          treeAfter:  OrderedDictionary<String, Any>  = ["A.hs": payload1, "D.hs": payload2, "C.hs": payload1]

      let result = performOnFolder(folder: try FullFolder<Payload>(tree: treeBefore)) { folder in
        XCTAssert(folder.rename(name: "B.hs", to: "D.hs", dontMove: true), "Renaming failed")
      }

      let resultModel = FileTree(files: FileOrFolder(folder: try FullFolder<Payload>(tree: treeAfter)))
      XCTAssert(try resultModel.snapshot().sameContents(fileOrFolder: result), "Contents doesn't match")
    }

    func testRenameMove() throws {

      let payload1                                    = Payload(text: "main = print 42"),
          payload2                                    = Payload(text: "main = print ?"),
          treeBefore: OrderedDictionary<String, Any>  = ["A.hs": payload1, "B.hs": payload2, "C.hs": payload1],
          treeAfter:  OrderedDictionary<String, Any>  = ["A.hs": payload1, "C.hs": payload1, "D.hs": payload2]

      let result = performOnFolder(folder: try FullFolder<Payload>(tree: treeBefore)) { folder in
        XCTAssert(folder.rename(name: "B.hs", to: "D.hs", dontMove: false), "Renaming failed")
      }

      let resultModel = FileTree(files: FileOrFolder(folder: try FullFolder<Payload>(tree: treeAfter)))
      XCTAssert(try resultModel.snapshot().sameContents(fileOrFolder: result), "Contents doesn't match")
    }

    func testRenameClash() throws {

      let payload                               = Payload(text: "main = print 42"),
          tree: OrderedDictionary<String, Any>  = ["A.hs": payload, "B.hs": payload, "C.hs": payload]

      var initialFolder: Folder<File<Payload>, Payload>!
      let result = performOnFolder(folder: try FullFolder<Payload>(tree: tree)) { folder in
        initialFolder = try! folder.snapshot()
        XCTAssertFalse(folder.rename(name: "B.hs", to: "C.hs"), "Renaming incorrectly succeded")
      }
      XCTAssert(result.sameContents(fileOrFolder: FileOrFolder(folder: initialFolder)), "Contents doesn't match")
    }
  }
