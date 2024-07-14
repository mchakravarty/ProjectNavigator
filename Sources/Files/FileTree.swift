//
//  FileTree.swift
//  
//
//  Created by Manuel M T Chakravarty on 17/09/2022.
//
//  File tree objects that separate the tree structure from the file contents, to facilitate editing file trees and
//  their contents in SwiftUI navigation split views.

import System
import Observation
import SwiftUI


// MARK: -
// MARK: File trees

// TODO: There are quite a few invariants of this structure that need to be documented and tested.

/// A file and folder tree structure with separated out and uuid-addressable files.
///
@Observable
public final class FileTree<Contents: FileContents> {

  /// The root of the file tree.
  ///
  /// The property is public, so that we can take a binding. However, modifications ought to happen via the provided
  /// file operations to ensure the consistent change of all derived information maintained by the file tree.
  ///
  /// Implicitly optional to allow for a circular dependency during initialisation.
  /// 
  public var root: ProxyFileOrFolder<Contents>!

  /// All files contained in the file tree.
  ///
  private var files: [UUID: File<Contents>] = [:]

  /// The relative path of all files and folders of this file tree *without* the root name.
  ///
  @ObservationIgnored
  private var filePaths: [UUID: FilePath] = [:]


  // MARK: Initialisers

  /// Produce a file tree from a folder structure with full files.
  ///
  public init(files: FullFileOrFolder<Contents>) {
    self.root = nil   // Need to init all properties before being able to use `self`.
    self.root = files.proxy(within: self)
  }

  /// Clone a file tree.
  ///
  public init(fileTree: FileTree<Contents>) {
    self.root      = fileTree.root
    self.files     = fileTree.files
    self.filePaths = fileTree.filePaths
  }

  
  // MARK: Adding and removing files

  /// Add a file to the file tree, returning it's proxy.
  ///
  internal func addFile(file: File<Contents>) -> File<Contents>.Proxy {
    files.updateValue(file, forKey: file.id)
    return File.Proxy(id: file.id, within: self)
  }

  /// Remove all files contained in a subtree.
  ///
  /// - Parameter item: The subtree whose files are to be removed.
  ///
  /// Also removes the file paths of all affected files and folders.
  ///
  internal func removeContainedFiles<FileType: FileProtocol>(item: FileOrFolder<FileType, Contents>) {
    switch item {
    case .file(let file):
      files.removeValue(forKey: file.id)
    case .folder(let folder):
      for item in folder.children.values { removeContainedFiles(item: item) }
    }
    filePaths.removeValue(forKey: item.id)
  }


  // MARK: File tree operations

  /// Flush all files in the file tree.
  ///
  public func flush() throws {
    for var file in files.values {
      try file.flush()
    }
  }

  /// Yield a flushed full tree representation of the file tree.
  ///
  /// The files in the file tree are flushed after this as well.
  ///
  public func snapshot() throws -> FullFileOrFolder<Contents> {
    try flush()
    return try root.snapshot()
  }

  /// The file id map of the file tree.
  ///
  public var fileIDMap: FileIDMap { root.fileIDMap }

  /// Yield the proxy for a uuid in this file tree.
  ///
  /// - Parameter fileId: The uuid whose proxy is being requested.
  /// - Returns: The proxy matching the given uuid.
  ///
  /// There is no guarantee that this proxy is *valid* in the file tree. This can be easily determined, though, by
  /// checking whether the `file` property of the returned proxy is non-nil.
  ///
  public func proxy(for fileId: UUID) -> File<Contents>.Proxy { File<Contents>.Proxy(id: fileId, within: self) }


  // MARK: Internal file lookup and update

  /// Determine the file identified by the given uuid, if any.
  ///
  /// - Parameter fileId: The uuid to look up.
  /// - Returns: The resulting full file, or nil if there is no matching file in this file tree.
  ///
  internal func lookup(fileId: UUID) -> File<Contents>? { files[fileId] }

  /// Update a given file if it exists in this file tree.
  ///
  /// - Parameter file: The file to update.
  ///
  internal func update(file: File<Contents>) { if files[file.id] != nil { files.updateValue(file, forKey: file.id) } }


  // MARK: File path cache

  /// Yield the file path assoicated with the item whose `UUID` is given.
  ///
  /// - Parameter id: The `UUID` of the item whose file path ought to be returned.
  /// - Returns: The file path of the specified item.
  ///
  /// Returns the empty file path for the root item or any unknown item.
  ///
  public func filePath(of id: UUID) -> FilePath { filePaths[id] ?? FilePath() }

  /// Adds the file path for an item located within a given folder.
  ///
  /// - Parameters:
  ///   - id: The `UUID` of the item whose file path is to be added.
  ///   - name: The item's file name.
  ///   - folder: The `UUID` of the folder containing the item.
  ///
  internal func addFilePath(of id: UUID, named name: String, within folder: UUID) {
    filePaths[id] = filePath(of: folder).appending(name)
  }

  /// Removes the file path for the item whose `UUID` is given.
  ///
  /// - Parameter of: The `UUID` whose associated file path ought to be removed.
  ///
  internal func removeFilePath(of id: UUID) {
    filePaths.removeValue(forKey: id)
  }


  // MARK: Set file tree

  /// Set the current file tree's payload to the values of the given file tree.
  ///
  /// - Parameter fileTree: The file tree whose contents ought to be copied.
  ///
  public func set(to fileTree: FileTree<Contents>) {
    root      = fileTree.root
    files     = fileTree.files
    filePaths = fileTree.filePaths
  }
}


// MARK: -
// MARK: Binding support for file proxies.

extension File.Proxy {

  /// Yield a SwiftUI binding to the file represented by a proxy.
  /// 
  public var binding: Binding<File<Contents>?> {
    return Binding { file } set: { newValue in
      
      if let newFile = newValue {

        // Assigning a file with a different id makes no sense.
        if newFile.id == id { fileTree?.update(file: newFile) }
        
      }
    }
  }
}
