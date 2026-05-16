//
//  FolderOverwriteTest.swift
//  ProjectNavigator
//
//  Created by Manuel M T Chakravarty on 16/05/2026.
//

import Foundation
import Testing
import OrderedCollections

@testable import Files
import _FilesTestSupport

@Suite("Folder Overwrite")
struct FolderOverwriteTest {

  @Test("Overwrite single file")
  func testSingleFile() throws {

    let payload                              = Payload(text: "main = print 42"),
        tree: OrderedDictionary<String, Any> = ["Main.hs": payload]

    // File tree before overwriting
    let folder   = try FullFolder<Payload>(tree: tree),
        fileTree = FileTree(files: FileOrFolder(folder: folder))

    // File wrapper for overwriting
    let directoryFileWrapper = FileWrapper(directoryWithFileWrappers:
                                            ["Main.hs": FileWrapper(regularFileWithContents:
                                                                      "main = print 43".data(using: .utf8)!)])

    try fileTree.root.folder?.overwrite(with: directoryFileWrapper, preserveUnsavedEdits: false)
    let snapshort = try fileTree.snapshot()
    #expect(snapshort.folder?.children["Main.hs"]?.file?.contents.text == "main = print 43")
  }

  @Test("Preserve single file")
  func testSingleFilePreserve() throws {

    let payload                              = Payload(text: "main = print 42"),
        tree: OrderedDictionary<String, Any> = ["Main.hs": payload]

    // File tree before overwriting
    let folder   = try FullFolder<Payload>(tree: tree),
        fileTree = FileTree(files: FileOrFolder(folder: folder))

    // File wrapper for overwriting
    let directoryFileWrapper = FileWrapper(directoryWithFileWrappers:
                                            ["Main.hs": FileWrapper(regularFileWithContents:
                                                                      "main = print 43".data(using: .utf8)!)])

    try fileTree.root.folder?.overwrite(with: directoryFileWrapper, preserveUnsavedEdits: true)
    let snapshort = try fileTree.snapshot()
    #expect(snapshort.folder?.children["Main.hs"]?.file?.contents.text == "main = print 42")
  }

  @Test("Overwrite single file with folder")
  func testSingleFileWithFolder() throws {

    let payload                              = Payload(text: "Bla"),
        tree: OrderedDictionary<String, Any> = ["text": payload]

    // File tree before overwriting
    let folder   = try FullFolder<Payload>(tree: tree),
        fileTree = FileTree(files: FileOrFolder(folder: folder))

    // File wrapper for overwriting
    let directoryFileWrapper = FileWrapper(directoryWithFileWrappers:
                                            ["text":
                                              FileWrapper(directoryWithFileWrappers:
                                                            ["Main.hs":
                                                              FileWrapper(regularFileWithContents:
                                                                            "main = print 43".data(using: .utf8)!)])])

    try fileTree.root.folder?.overwrite(with: directoryFileWrapper, preserveUnsavedEdits: false)
    let snapshort = try fileTree.snapshot()
    #expect(snapshort.folder?.children["text"]?.folder != nil, "'text' ought to be a folder")
    #expect(snapshort.folder?.children["text"]?.folder?.children["Main.hs"]?.file?.contents.text == "main = print 43")
  }

  @Test("Overwrite single file within folder")
  func testSingleFileWithinFolder() throws {

    let payload                                 = Payload(text: "main = print 42"),
        subtree: OrderedDictionary<String, Any> = ["Main.hs": payload],
        tree: OrderedDictionary<String, Any>    = ["text": subtree]

    // File tree before overwriting
    let folder   = try FullFolder<Payload>(tree: tree),
        fileTree = FileTree(files: FileOrFolder(folder: folder))

    // File wrapper for overwriting
    let directoryFileWrapper = FileWrapper(directoryWithFileWrappers:
                                            ["text":
                                              FileWrapper(directoryWithFileWrappers:
                                                            ["Main.hs":
                                                              FileWrapper(regularFileWithContents:
                                                                            "main = print 43".data(using: .utf8)!)])])

    try fileTree.root.folder?.overwrite(with: directoryFileWrapper, preserveUnsavedEdits: false)
    let snapshort = try fileTree.snapshot()
    #expect(snapshort.folder?.children["text"]?.folder?.children["Main.hs"]?.file?.contents.text == "main = print 43")
  }
}
