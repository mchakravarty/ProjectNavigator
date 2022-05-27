//
//  FileOperations.swift
//  
//
//  Created by Manuel M T Chakravarty on 26/05/2022.
//

import Foundation


extension Folder {

  /// Add a new item to the given folder.
  ///
  /// - Parameters:
  ///   - item: The item to be added.
  ///   - preferredName: The preferred name to be used for the new item if it doesn't collide with an existing name. In
  ///       case of a collision, the preferred name will be varied to be unique. If we don't find a unqiue name within
  ///       100 attempts, the item will not be inserted.
  ///   - index: Optional index at which to insert the new item into the ordered set of children. If no index is given,
  ///       the new child will be added at the first position where it fits alphabetically.
  ///
  mutating func add(item: FileOrFolder<Contents>, withPreferredName preferredName: String, at index: Int? = nil) {

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
      children.updateValue(item,
                           forKey: name,
                           insertingAt: insertionIndex > children.keys.endIndex ? children.keys.endIndex : insertionIndex)
                             // ...in case the caller passes an out of range index
    }
  }
}
