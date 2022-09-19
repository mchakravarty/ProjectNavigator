//
//  FileTree.swift
//  
//
//  Created by Manuel M T Chakravarty on 17/09/2022.
//
//  File tree objects that separate the tree structure from the file contents, to facilitate editing file trees and
//  their contents in SwiftUI navigation split views.

import SwiftUI


// MARK: -
// MARK: File trees

// TODO: There are quite a few invariants of this structure that need to be documented and tested.

/// A file and folder tree structure with separated out and uuid-addressable files.
///
public final class FileTree<Contents: FileContents>: ObservableObject {

  /// The root of the file tree.
  ///
  /// Implicitly optional to allow for a circular dependency during initialisation.
  /// 
  @Published public var root: ProxyFileOrFolder<Contents>!

  /// All files contained in the file tree.
  ///
  @Published private var files: [UUID: File<Contents>] = [:]


  // MARK: Initialisers

  /// Produce a file tree from a folder structure with full files.
  ///
  public init(files: FullFileOrFolder<Contents>) {
    self.root = nil   // Need to init all properties before being able to use `self`.
    self.root = files.proxy(within: self)
  }


  // MARK: Adding and removing files

  /// Add a file to the file tree, returning it's proxy.
  ///
  public func addFile(file: File<Contents>) -> File<Contents>.Proxy {
    files.updateValue(file, forKey: file.id)
    return File.Proxy(id: file.id, within: self)
  }

  /// Remove all files contained in a subtree.
  ///
  /// - Parameter item: The subtree whose files are to be removed.
  ///
  public func removeContainedFiles<FileType: FileProtocol>(item: FileOrFolder<FileType, Contents>) {
    switch item {
    case .file(let file):
      files.removeValue(forKey: file.id)
    case .folder(let folder):
      for item in folder.children.values { removeContainedFiles(item: item) }
    }
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
  /// - Parameter file: The fiel to update.
  ///
  internal func update(file: File<Contents>) { if files[file.id] != nil { files.updateValue(file, forKey: file.id) } }
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
