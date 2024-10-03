//
//  FileOperations.swift
//  
//
//  Created by Manuel M T Chakravarty on 26/05/2022.
//

import Foundation
import os


private let logger = Logger(subsystem: "org.justtesting.BundleNavigator", category: "FileOperations")


extension Folder {

  /// Add a new item to a folder.
  ///
  /// - Parameters:
  ///   - item: The item to be added.
  ///   - preferredName: The preferred name to be used for the new item if it doesn't collide with an existing name. In
  ///       case of a collision, the preferred name will be varied to be unique. If we don't find a unqiue name within
  ///       100 attempts, the item will not be inserted.
  ///   - index: Optional index at which to insert the new item into the ordered set of children. If no index is given,
  ///       the new child will be added at the first position where it fits alphabetically.
  /// - Returns:If successful, the name under which the item was added.
  ///
  /// This function only works on folders in proxy trees. (It would be easy to provide a corresponding version on
  /// folders containing full files.)
  ///
  @discardableResult
  public mutating func add(item: FullFileOrFolder<Contents>,
                           withPreferredName preferredName: String,
                           at index: Int? = nil)
  -> String?
  where FileType == File<Contents>.Proxy
  {
    // Folders in proxy tree must have a file tree set.
    guard let fileTree else {
      logger.error("Folder.add(item:withPreferredName:at:) in a proxy tree without having a file tree set")
      return nil
    }

    let ext  = (preferredName as NSString).pathExtension,
        base = (preferredName as NSString).deletingPathExtension

    func determineName(attempt: Int) -> String {
      let suffix = ext == "" ? "" : "." + ext
      if attempt == 0 { return base + suffix }
      else { return "\(base)\(attempt)\(suffix)" }
    }

    // Find an unused name
    var finalName: String? = nil
    for attempt in 0...100 {
      let name = determineName(attempt: attempt)
      if !children.keys.contains(name) || attempt > 100 { finalName = name; break }
    }

    // If we found an unused name, insert the item
    if let name = finalName {

      // Add the file path of the added item. (The file path of subitems will be added by the subsequent `proxy` call.)
      fileTree.addFilePath(of: item.id, named: name, within: id)

      let insertionIndex = index ?? children.keys.firstIndex{ $0 > name } ?? children.keys.endIndex
      children.updateValue(item.proxy(within: fileTree),
                           forKey: name,
                           insertingAt: insertionIndex > children.keys.endIndex ? children.keys.endIndex : insertionIndex)
                             // ...in case the caller passes an out of range index

    }
    return finalName
  }

  /// Remove the item with the given name from the a folder.
  ///
  /// - Parameter name: The name of the item to be removed.
  /// - Returns: The removed item or `nil` if there was no item of that name.
  ///
  @discardableResult
  public mutating func remove(name: String) -> FileOrFolder<FileType, Contents>? {

    if let index = children.index(forKey: name) {

      let item = children.remove(at: index).value
      fileTree?.removeContainedFiles(item: item)      // NB: this will also remove the file paths
      return item

    } else { return nil }
  }

  /// Rename the item with to the given new name.
  ///
  /// - Parameters:
  ///   - name: The current name of the item.
  ///   - newName: The new name that the item ought to assume.
  ///   - dontMove: `true` iff the renamed item should keep its position in the ordered dictionary of children;
  ///       otherwise, the renamed item will be moved to the first position where it fits alphabetically.
  /// - Returns: `true` iff the item exists and now carries the name `newName`.
  ///
  @discardableResult
  public mutating func rename(name: String, to newName: String, dontMove: Bool = false) -> Bool {

    // Apply renaming recursively down the tree.
    func renameFilePaths(of item: FileOrFolder<FileType,Contents>, named name: String, within folder: UUID) {
      fileTree?.addFilePath(of: item.id, named: name, within: folder)
      switch item {
      case .file: break
      case .folder(let folder):
        for child in folder.children { renameFilePaths(of: child.value, named: child.key, within: folder.id) }
      }
    }

    if name == newName || !children.keys.contains(newName),      // crucial to test for collision *before* removing
       let index = children.index(forKey: name)
    {

      let item     = children.remove(at: index).value,
          newIndex = dontMove ? index : children.keys.firstIndex{ $0 > newName } ?? children.keys.endIndex
      children.updateValue(item, forKey: newName, insertingAt: newIndex)
      renameFilePaths(of: item, named: newName, within: id)
      return true

    } else { return false }
  }
}
