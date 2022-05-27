//
//  Files.swift
//
//
//  Created by Manuel M T Chakravarty on 28/04/2022.
//
//  Abstraction for a tree of files and folders together with marshalling from and to file wrappers as well as the
//  persistent association of `UUID`s.
//
//  * File and folder names are not stored in the items themselves, but associated externally (and passed down the tree
//    in a traversal).
//  * We separate flushing of dirty files into file wrappers from computing a file wrapper tree for folders to
//    facilitate the two phase writing of `ReferenceFileDocuments`. Flushing does minimal work and all necessary
//    mutation on the document. Its result can, then, save as an immutable snapshot to be subsequently serialised and
//    written.


import Foundation
import os
import OrderedCollections


private let logger = Logger(subsystem: "org.justtesting.BundleNavigator", category: "Files")


/// A file id map associates `UUID`s with files and folders of a file tree.
///
public struct FileIDMap: Codable {
  let id:       UUID
  var children: [String: FileIDMap]
}

/// Payload protocol for file contents. Concrete playload types need to be value types.
///
public protocol FileContents: Equatable {

  /// Create a representation of the contents of a file.
  ///
  /// - Parameters:
  ///   - name: The name of the file including its file extension.
  ///   - data: The data contained in the file.
  ///
  init(name: String, data: Data) throws

  /// Yield the file's data.
  ///
  func data() throws -> Data

  /// To be called before before extracting `data` to facilitate caching expensive serialisation if any.
  ///
  mutating func flush() throws
}


// MARK: -
// MARK: File

/// Represents a single file (i.e., a leaf of a folder tree).
///
public struct File<Contents: FileContents>: Identifiable {
  public let id: UUID

  /// Application-specific representation of the file contents.
  ///
  public var contents: Contents {
    didSet { cleanFileWrapper = nil }
  }

  /// The file wrapper from which this item was created (if any) or that the item was flushed into. The property is
  /// `nil` unless the contents and the file wrapper contents coincide. In other words, the item is dirty exactly if
  /// the file wrapper is absent.
  ///
  private var cleanFileWrapper: FileWrapper?


  // MARK: Initialisers

  /// Create an file item with the specified contets.
  ///
  /// - Parameters:
  ///   - contents: The file contents.
  ///   - filewrapper: Optional file wrapper representing the given `contents`.
  ///   - persistentID: Persistent identifier that get's created at initialisation time if not already provided.
  ///
  public init(contents: Contents, fileWrapper: FileWrapper? = nil, persistentID uuid: UUID = UUID()) {
    id                    = uuid
    self.contents         = contents
    self.cleanFileWrapper = fileWrapper?.isRegularFile == true ? fileWrapper : nil
  }

  /// Initialise a file from a file wrapper.
  ///
  /// - Parameters:
  ///   - fileWrapper: The file wrapper whose contents is to be represented by the file item.
  ///   - persistentIDMap: Contains the available persistent ids for this item and its children. If the map is not
  ///       available, new ids are generated.
  ///
  public init(fileWrapper: FileWrapper, persistentIDMap fileMap: FileIDMap? = nil) throws {
    let filename = fileWrapper.filename ?? fileWrapper.preferredFilename ?? "unknown"

    guard fileWrapper.isRegularFile,
          let data = fileWrapper.regularFileContents
    else {

      logger.error("File wrapper '\(filename)' could not be read as a regular file")
      throw CocoaError(.fileReadUnknown)

    }

    let contents = try Contents(name: filename, data: data)
    self.init(contents: contents, fileWrapper: fileWrapper, persistentID: fileMap?.id ?? UUID())
  }


  // MARK: Queries

  /// Check whether the contents of self and the given file are the same.
  ///
  /// - Parameter file: The file whose contents we compare to.
  /// - Returns: Whether the contents of the two files is the same.
  ///
  public func sameContents(file: File<Contents>) -> Bool { contents == file.contents }


  // MARK: Serialisation

  /// Flush contents into a new file wrapper if this file is dirty.
  ///
  public mutating func flush() throws {
    try contents.flush()
    if cleanFileWrapper == nil { cleanFileWrapper = try FileWrapper(regularFileWithContents: contents.data()) }
  }

  /// Yield an up to date file wrapper for the file contents.
  ///
  public func fileWrapper() throws -> FileWrapper {
    if let fileWrapper = cleanFileWrapper {

      return fileWrapper

    } else {

      return  try FileWrapper(regularFileWithContents: contents.data())

    }
  }

  /// Yield a file map for this file.
  ///
  public var fileIDMap: FileIDMap { FileIDMap(id: id, children: [:]) }
}


// MARK: -
// MARK: File or folder

/// Represents a filr or folder item.
///
public enum FileOrFolder<Contents: FileContents>: Identifiable {
  case file(File<Contents>)
  case folder(Folder<Contents>)

  public var id: UUID {
    switch self {
    case .file(let file):     return file.id
    case .folder(let folder): return folder.id
    }
  }

  // MARK: Initialisers

  /// Create a file variant from a given file.
  ///
  /// - Parameter file: The file that ought to be wrapped.
  ///
  public init(file: File<Contents>) { self = .file(file) }

  /// Create a folder variant from a given folder.
  ///
  /// - Parameter folder: The folder that ought to be wrapped.
  ///
  public init(folder: Folder<Contents>) { self = .folder(folder) }

  /// Create a file or folder from a file wrapper.
  ///
  /// - Parameters:
  ///   - fileWrapper: The file wrapper whose contents is to be represented by the item.
  ///   - persistentIDMap: Contains the available persistent ids for this item and its children. If the map is not
  ///       available, new ids are generated.
  ///
  public init(fileWrapper: FileWrapper, persistentIDMap fileMap: FileIDMap? = nil) throws {

    if fileWrapper.isRegularFile {

      self = .file(try File(fileWrapper: fileWrapper, persistentIDMap: fileMap))

    } else if let fileWrappers = fileWrapper.fileWrappers {

      self = .folder(try Folder<Contents>(fileWrappers: fileWrappers, persistentIDMap: fileMap))

    } else {

      let name = fileWrapper.preferredFilename ?? fileWrapper.filename ?? "<unknown name>"
      logger.error("File wrapper for '\(name)' could not be decoded")
      throw CocoaError(.fileReadCorruptFile)

    }
  }

  // MARK: Queries

  /// Check whether the contents of self and the given file or folder are the same.
  ///
  /// - Parameter fileOrFolder: The file or folder whose contents we compare to.
  /// - Returns: Whether the contents of the two items is the same.
  ///
  public func sameContents(fileOrFolder: FileOrFolder<Contents>) -> Bool {
    switch self {

    case .file(let selfFile):
      if case let .file(file) = fileOrFolder { return selfFile.sameContents(file: file) } else { return false }

    case .folder(let selfFolder):
      if case let .folder(folder) = fileOrFolder { return selfFolder.sameContents(folder: folder) } else { return false }

    }
  }


  // MARK: Serialisation

  /// Flush the contents of all contained files.
  ///
  public mutating func flush() throws {
    switch self {
    case .file(var file):     try file.flush()
    case .folder(var folder): try folder.flush()
    }
  }

  /// Yield an up to date file wrapper for the file contents or folder.
  ///
  public func fileWrapper() throws -> FileWrapper {
    switch self {
    case .file(let file):     return try file.fileWrapper()
    case .folder(let folder): return try folder.fileWrapper()
    }
  }

  /// Yield this item's file map.
  ///
  public var fileIDMap: FileIDMap {
    switch self {
    case .file(let file):     return file.fileIDMap
    case .folder(let folder): return folder.fileIDMap
    }
  }
}


// MARK: -
// MARK: Folder

/// Represents a folder containing subitems.
///
public struct Folder<Contents: FileContents>: Identifiable {
  public let id: UUID

  /// The subitems contained in the folder.
  ///
  public var children: OrderedDictionary<String, FileOrFolder<Contents>>


  // MARK: Initialisers

  /// Create an file item with the specified set of children.
  ///
  /// - Parameters:
  ///   - children: The folders *ordered* children.
  ///   - persistentID: Persistent identifier that get's created at initialisation time if not already provided.
  ///
  public init(children: OrderedDictionary<String, FileOrFolder<Contents>>, persistentID uuid: UUID = UUID()) {
    id            = uuid
    self.children = children
  }

  /// Create a folder from a contents tree. This is, in particular, useful for writing tests.
  ///
  /// - Parameter tree: A nested *ordered* dictionary structure describing the contents of a folder with `Contents` at
  ///     the leaves.
  ///
  public init(tree: OrderedDictionary<String, Any>) throws {
    id       = UUID()
    children = OrderedDictionary(uniqueKeysWithValues: try tree.mapValues{ child in

      if let contents = child as? Contents { return FileOrFolder(file: File(contents: contents)) }
      else if let subTree = child as? OrderedDictionary<String, Any> {

        return FileOrFolder(folder: try Folder(tree: subTree))

      } else {

        logger.error("Folder(tree:) unknown type of child")
        throw CocoaError(.coderInvalidValue)

      }
    })
  }

  /// Create an file item with the specified set of children.
  ///
  /// - Parameters:
  ///   - fileWrappers: The file wrappers representing the folder's children.
  ///   - persistentIDMap: Contains the available persistent ids for this folder and its children. If the map is not
  ///       available, new ids are generated.
  ///
  public init(fileWrappers: [String: FileWrapper], persistentIDMap fileMap: FileIDMap?) throws {
    let children = try fileWrappers.map{
      (key: String, value: FileWrapper) in
        (key, try FileOrFolder<Contents>(fileWrapper: value, persistentIDMap: fileMap?.children[key])) }
    self.init(children: OrderedDictionary(uniqueKeysWithValues: children), persistentID: fileMap?.id ?? UUID())
  }


  // MARK: Queries

  /// Check whether the contents of self and the given folder are the same.
  ///
  /// - Parameter folder: The folder whose contents we compare to.
  /// - Returns: Whether the contents of the two folders is the same.
  ///
  public func sameContents(folder: Folder<Contents>) -> Bool {
    if children.keys != folder.children.keys { return false }

    return children.reduce(true){ (result, element) in
      return result && (folder.children[element.key]?.sameContents(fileOrFolder: element.value) == true)
    }
  }


  // MARK: Serialisation

  /// Flush the contents of all contained files.
  ///
  public mutating func flush() throws {
    for (_, var fileOrFolder) in children { try fileOrFolder.flush() }
  }

  /// Yield an up to date file wrapper for the folder.
  ///
  public func fileWrapper() throws -> FileWrapper {
    return FileWrapper(directoryWithFileWrappers:
                        try Dictionary(uniqueKeysWithValues: zip(children.keys,
                                                                 children.values.map{ try $0.fileWrapper() })))
  }

  /// Yield this item's file map.
  ///
  public var fileIDMap: FileIDMap {
    FileIDMap(id: id,
              children: Dictionary(uniqueKeysWithValues: zip(children.keys, children.values.map{ $0.fileIDMap })))
  }
}
