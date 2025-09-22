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
  /// Returns the empty file path for the root item and nil for any unknown item.
  ///
  public func filePath(of id: UUID) -> FilePath? {
    // NB: This function is indirectly used in the initialiser before 'root' is being set to a non-nil value. We
    //     handle this special case separately, assuming any unknown id gets the root path.
    if root == nil { filePaths[id] ?? FilePath() }
    else {
      if id == root.id { FilePath() } else { filePaths[id] }
    }
  }

  /// Adds the file path for an item located within a given folder.
  ///
  /// - Parameters:
  ///   - id: The `UUID` of the item whose file path is to be added.
  ///   - name: The item's file name.
  ///   - folder: The `UUID` of the folder containing the item.
  ///
  /// Ignore if the `folder` does not have a file path.
  ///
  internal func addFilePath(of id: UUID, named name: String, within folder: UUID) {
    filePaths[id] = filePath(of: folder)?.appending(name)
  }

  /// Removes the file path for the item whose `UUID` is given.
  ///
  /// - Parameter of: The `UUID` whose associated file path ought to be removed.
  ///
  internal func removeFilePath(of id: UUID) {
    filePaths.removeValue(forKey: id)
  }


  // MARK: File path lookup
  
  /// Determine the file or folder identified by a given file path.
  ///
  /// - Parameter filePath: The file path whose file or folder ought to be determined.
  /// - Returns: The file or folder at the given file path.
  ///
  public func lookup(filePath: FilePath) -> ProxyFileOrFolder<Contents>? {
    var components = filePath.components
    var current: ProxyFileOrFolder<Contents> = root
    while !components.isEmpty {

      let component = components.removeFirst()  // We know that `components` is not empty.
      switch current {

        // As long as we have unresolved components, we shouldn't have hit a file yet.
      case .file:
        return nil

      case .folder(let folder):
        if let child = folder.children[String(decoding: component)] {
          current = child
        } else {
          return nil   // The name does not occur in the dictionary of children.
        }

      }
    }
    return current
  }
  
  /// Look the folder at the given path. If there is no folder, return `nil`.
  ///
  /// - Parameter folderPath: The path at which we look up the folder.
  /// - Returns: The folder at the given path, if any.
  ///
  public func lookup(folderAt folderPath: FilePath) -> ProxyFolder<Contents>? {
    guard case let .folder(root) = root else { return nil }

    func lookup(components: FilePath.ComponentView, in folder: ProxyFolder<Contents>) -> ProxyFolder<Contents>? {
      if let component               = components.first,
         case let .folder(subFolder) = folder.children[String(decoding: component)]
      {
        return lookup(components: FilePath.ComponentView(components.dropFirst()), in: subFolder)

      } else if components.isEmpty {

        return folder

      } else {

        return nil

      }
    }
    return lookup(components: folderPath.components, in: root)
  }

  /// Set the folder at the given path to a new value. If there is no folder at that path or if it has an id other
  /// than that of the updating folder value, we do nothing.
  ///
  /// - Parameters:
  ///   - folderPath: The path at which to replace the folder value.
  ///   - newFolder: The new folder value.
  ///
  public func set(folderAt folderPath: FilePath, to newFolder: ProxyFolder<Contents>) {

    func set(components: FilePath.ComponentView, in node: inout ProxyFileOrFolder<Contents>) {
      if let component            = components.first,
         case var .folder(folder) = node,
         var subNode              = folder.children[String(decoding: component)]
      {
        set(components: FilePath.ComponentView(components.dropFirst()), in: &subNode)
        folder.children[String(decoding: component)] = subNode
        node = .folder(folder)

      } else if components.isEmpty {

        if node.id == newFolder.id { node = .folder(newFolder) }

      }
    }
    set(components: folderPath.components, in: &root)
  }

//  NB: There seems little point in this more general function as proxy files only carry an id, which we never change
//      during an udpate.
//  public func set(fileOrFolderAt filePath: FilePath, to newFileOrFolder: ProxyFileOrFolder<Contents>) {
//
//    func set(components: FilePath.ComponentView, in node: inout ProxyFileOrFolder<Contents>) {
//      if let component            = components.first,
//         case var .folder(folder) = node,
//         var subNode              = folder.children[String(decoding: component)]
//      {
//        set(components: FilePath.ComponentView(components.dropFirst()), in: &subNode)
//        folder.children[String(decoding: component)] = subNode
//        node = .folder(folder)
//
//      } else if components.isEmpty {
//
//        // Only update with a new version of the same node.
//        if node.id == newFileOrFolder.id { node = newFileOrFolder }
//
//      }
//    }
//    set(components: filePath.components, in: &root)
//  }


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
// MARK: Binding support for file and folder proxies.

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

extension Folder {

  // FIXME: This could be generalised to all folders (not just proxies), but is that useful?
  /// Yield a SwiftUI binding for the current proxy folder on the basis of its path.
  ///
  /// The returned binding is stable wrt to changes in the file tree as we look up the path via the folder's id.
  ///
  public var pathBinding: Binding<ProxyFolder<Contents>?> {
    guard let fileTree else { return .constant(nil) }

    return Binding {
      if let filePath = fileTree.filePath(of: id) { fileTree.lookup(folderAt: filePath) } else { nil }

    } set: { newValue in
      if let newFolder = newValue,
         let filePath = fileTree.filePath(of: id)
      {
        fileTree.set(folderAt: filePath, to: newFolder)
      }
    }
  }
}
