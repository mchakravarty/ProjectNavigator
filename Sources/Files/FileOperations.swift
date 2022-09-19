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
  ///
  /// This function only works on folders in proxy trees. (It would be easy to provide a corresponding version on
  /// folders containing full files.)
  ///
  public mutating func add(item: FileOrFolder<File<Contents>, Contents>,
                           withPreferredName preferredName: String,
                           at index: Int? = nil)
  where FileType == File<Contents>.Proxy
  {
    // Folders in proxy tree must have a file tree set.
    guard let fileTree else {
      logger.error("Folder.add(item:withPreferredName:at:) in a proxy tree with having a file tree set")
      return
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
      let insertionIndex = index ?? children.keys.firstIndex{ $0 > name } ?? children.keys.endIndex
      children.updateValue(item.proxy(within: fileTree),
                           forKey: name,
                           insertingAt: insertionIndex > children.keys.endIndex ? children.keys.endIndex : insertionIndex)
                             // ...in case the caller passes an out of range index
    }
  }

  /// Remove the item with the given name from the a folder.
  ///
  /// - Parameter name: The name of the item to be removed.
  /// - Returns: The removed item or `nil` if there was no item of that name.
  ///
  public mutating func remove(name: String) -> FileOrFolder<FileType, Contents>? {

    if let index = children.index(forKey: name) {

      let item = children.remove(at: index).value
      fileTree?.removeContainedFiles(item: item)
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
  public mutating func rename(name: String, to newName: String, dontMove: Bool = false) -> Bool {
    if name == newName || !children.keys.contains(newName),      // crucial to test for collision *before* removing
       let index = children.index(forKey: name)
    {

      let item     = children.remove(at: index).value,
          newIndex = dontMove ? index : children.keys.firstIndex{ $0 > newName } ?? children.keys.endIndex
      children.updateValue(item, forKey: newName, insertingAt: newIndex)
      return true

    } else { return false }
  }
}
