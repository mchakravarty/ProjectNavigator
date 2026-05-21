//
//  FileTreeTests.swift
//  ProjectNavigator
//
//  Created by Manuel M T Chakravarty on 21/05/2026.
//

import Testing
import OrderedCollections

@testable import Files
import _FilesTestSupport

@Suite("FileTree basic tests")
struct FileTreeTests {

  @Test("Test file paths")
  func testFilePaths() throws {

    let payload                              = Payload(text: "main = print 42"),
        tree: OrderedDictionary<String, Any> = ["Main.hs": payload]

    let files    = try? FileOrFolder(folder: FullFolder<Payload>(tree: tree)),
        fileTree = FileTree(files: files!)

    #expect(fileTree.filePath(of: files!.folder!.children["Main.hs"]!.id) == "Main.hs")
  }
}
