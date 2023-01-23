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
//  * We define file proxies to enable storing the actual files contents separately from the tree structure. This
//    simplifies accessing files via their uuid, which in turn is crucial for using navigation split views.


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

/// The interface required of files in folder trees.
///
public protocol FileProtocol<Contents>: Identifiable, Equatable where ID == UUID {
  associatedtype Contents: FileContents

  func sameContents(file: Self) -> Bool

  func fileWrapper() throws -> FileWrapper
}

/// Represents a single file (i.e., a leaf of a folder tree).
///
public struct File<Contents: FileContents>: FileProtocol {

  public let id: UUID

  /// Id-only representation of a file aka file proxy.
  ///
  public struct Proxy: FileProtocol {
    public let id: UUID

    /// The file tree within which this file proxy has been created.
    ///
    /// NB:
    /// * In this manner, we can't accidentally use a proxy with the wrong file tree.
    /// * Needs to be weak to avoid a cycle.
    ///
    internal weak var fileTree: FileTree<Contents>?

    /// The file represented by the proxy.
    ///
    public var file: File? {
      get { fileTree?.lookup(fileId: id) }
    }

    public static func == (lhs: Proxy, rhs: Proxy) -> Bool { lhs.id == rhs.id }

    // Can only be created internally.
    internal init(id: UUID, within fileTree: FileTree<Contents>) {
      self.id       = id
      self.fileTree = fileTree
    }

    /// Check whether the contents of self and the given file are the same.
    ///
    /// - Parameter file: The file whose contents we compare to.
    /// - Returns: Whether the contents of the two files is the same.
    ///
    public func sameContents(file: Proxy) -> Bool { self.file?.contents == file.file?.contents }

    /// Serialise into a fil wrapper.
    ///
    public func fileWrapper() throws -> FileWrapper {
      if let theFile = file { return try theFile.fileWrapper() }
      else {

        logger.error("fileWrapper(): no file for proxy")
        throw CocoaError(.fileWriteUnknown)

      }
    }
  }

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

      return try FileWrapper(regularFileWithContents: contents.data())

    }
  }

  /// Yield a file map for this file.
  ///
  public var fileIDMap: FileIDMap { FileIDMap(id: id, children: [:]) }
}


// MARK: -
// MARK: File or folder

/// Represents a file or folder item, where the concrete type of files is a parameter.
///
public enum FileOrFolder<FileType: FileProtocol, Contents: FileContents>: Identifiable, Equatable {
  case file(FileType)
  case folder(Folder<FileType, Contents>)

  public var id: UUID {
    switch self {
    case .file(let file):     return file.id as UUID
    case .folder(let folder): return folder.id
    }
  }

  public static func == (lhs: FileOrFolder<FileType, Contents>, rhs: FileOrFolder<FileType, Contents>) -> Bool {
    lhs.id == rhs.id
  }


  // MARK: Initialisers

  /// Create a file variant from a given file.
  ///
  /// - Parameter file: The file that ought to be wrapped.
  ///
  public init(file: FileType) { self = .file(file) }

  /// Create a folder variant from a given folder.
  ///
  /// - Parameter folder: The folder that ought to be wrapped.
  ///
  public init(folder: Folder<FileType, Contents>) { self = .folder(folder) }


  // MARK: Queries

  /// Check whether the contents of self and the given file or folder are the same.
  ///
  /// - Parameter fileOrFolder: The file or folder whose contents we compare to.
  /// - Returns: Whether the contents of the two items is the same.
  ///
  public func sameContents(fileOrFolder: FileOrFolder<FileType, Contents>) -> Bool {
    switch self {

    case .file(let selfFile):
      if case let .file(file) = fileOrFolder { return selfFile.sameContents(file: file) } else { return false }

    case .folder(let selfFolder):
      if case let .folder(folder) = fileOrFolder { return selfFolder.sameContents(folder: folder) } else { return false }

    }
  }

  /// Yield an up to date file wrapper for the file contents or folder.
  ///
  public func fileWrapper() throws -> FileWrapper {
    switch self {
    case .file(let file):
      return try file.fileWrapper()

    case .folder(let folder):
      return try folder.fileWrapper()
    }
  }

  /// Yield this item's file map.
  ///
  public var fileIDMap: FileIDMap {
    switch self {
    case .file(let file):     return FileIDMap(id: file.id, children: [:])
    case .folder(let folder): return folder.fileIDMap
    }
  }
}


// MARK: Operations for files or folders of full files

extension FileOrFolder {

  /// Create a file or folder from a file wrapper.
  ///
  /// - Parameters:
  ///   - fileWrapper: The file wrapper whose contents is to be represented by the item.
  ///   - persistentIDMap: Contains the available persistent ids for this item and its children. If the map is not
  ///       available, new ids are generated.
  ///
  public init(fileWrapper: FileWrapper, persistentIDMap fileMap: FileIDMap? = nil) throws
  where FileType == File<Contents>
  {
    if fileWrapper.isRegularFile {

      self = .file(try File<Contents>(fileWrapper: fileWrapper, persistentIDMap: fileMap))

    } else if let fileWrappers = fileWrapper.fileWrappers {

      self = .folder(try Folder<FileType, Contents>(fileWrappers: fileWrappers, persistentIDMap: fileMap))

    } else {

      let name = fileWrapper.preferredFilename ?? fileWrapper.filename ?? "<unknown name>"
      logger.error("File wrapper for '\(name)' could not be decoded")
      throw CocoaError(.fileReadCorruptFile)

    }
  }

  /// Yield a proxy version of the current file or folder.
  ///
  public func proxy(within fileTree: FileTree<Contents>) -> FileOrFolder<File<Contents>.Proxy, Contents>
  where FileType == File<Contents>
  {
    switch self {
    case .file(let file):
      return .file(fileTree.addFile(file: file))

    case .folder(let folder):
      return .folder(folder.proxy(within: fileTree))
    }
  }
}


// MARK: Operations for files or folders of proxy files

extension FileOrFolder {

  /// Snapshot a proxy item into a full item.
  ///
  public func snapshot() throws -> FileOrFolder<File<Contents>, Contents>
  where FileType == File<Contents>.Proxy
  {
    switch self {
    case .file(let file):
      if let fullFile = file.file { return .file(fullFile) }
      else {

        logger.error("snapshot(): no file for proxy")
        throw CocoaError(.fileWriteUnknown)

      }

    case .folder(let folder):
      return .folder(try folder.snapshot())
    }
  }
}


// MARK: Type aliases

/// Folder cintaining full files.
///
public typealias FullFileOrFolder<Contents: FileContents> = FileOrFolder<File<Contents>, Contents>

/// Folder containing file proxies.
///
public typealias ProxyFileOrFolder<Contents: FileContents> = FileOrFolder<File<Contents>.Proxy, Contents>


// MARK: -
// MARK: Folder

/// Represents a folder containing subitems.
///
public struct Folder<FileType: FileProtocol, Contents: FileContents>: Identifiable, Equatable {
  public let id: UUID

  /// The subitems contained in the folder.
  ///
  public var children: OrderedDictionary<String, FileOrFolder<FileType, Contents>>

  /// The file tree within which this folder has been created *if* the folder contains file proxies.
  ///
  /// NB:
  /// * By being embedded in the folder, we can't accidentally use a folder with the wrong file tree.
  /// * Needs to be weak to avoid a cycle.
  ///
  internal weak var fileTree: FileTree<Contents>?

  public static func == (lhs: Folder<FileType, Contents>, rhs: Folder<FileType, Contents>) -> Bool { lhs.id == rhs.id }


  // MARK: Initialisers

  /// Create an folder item with the specified set of children.
  ///
  /// - Parameters:
  ///   - children: The folders *ordered* children.
  ///   - persistentID: Persistent identifier that get's created at initialisation time if not already provided.
  ///
  public init(children: OrderedDictionary<String, FileOrFolder<FileType, Contents>>,
              persistentID uuid: UUID = UUID(),
              within fileTree: FileTree<Contents>? = nil)
  {
    self.id       = uuid
    self.children = children
    self.fileTree = fileTree
  }


  // MARK: Queries

  /// Check whether the contents of self and the given folder are the same.
  ///
  /// - Parameter folder: The folder whose contents we compare to.
  /// - Returns: Whether the contents of the two folders is the same.
  ///
  public func sameContents(folder: Folder<FileType, Contents>) -> Bool {
    if children.keys != folder.children.keys { return false }

    return children.reduce(true){ (result, element) in
      return result && (folder.children[element.key]?.sameContents(fileOrFolder: element.value) == true)
    }
  }


  // MARK: Serialisation

  /// Yield an up to date file wrapper for the folder.
  ///
  public func fileWrapper() throws -> FileWrapper {

    // It's curcial that we set the dictionary keys as preferred file names as we keep the original versions of file
    // wrappers of unmodified as is (for efficiency) and they may contain an outdated file name if the file was renamed
    // in the meantime.
    let childrenAsFileWrappers = try children.map{ (key, value) in
      let fileWrapper = try value.fileWrapper()
      fileWrapper.preferredFilename = key
      return fileWrapper
    }
    return FileWrapper(directoryWithFileWrappers:
                        Dictionary(uniqueKeysWithValues: zip(children.keys, childrenAsFileWrappers)))
  }

  /// Yield this item's file map.
  ///
  public var fileIDMap: FileIDMap {
    FileIDMap(id: id,
              children: Dictionary(uniqueKeysWithValues: zip(children.keys, children.values.map{ $0.fileIDMap })))
  }
}


// MARK: Operations for folders of full files

extension Folder {

  /// Create a folder from a contents tree. This is, in particular, useful for writing tests.
  ///
  /// - Parameters:
  ///   - tree: A nested *ordered* dictionary structure describing the contents of a folder with `Contents` at
  ///       the leaves.
  ///   - persistentID: Persistent identifier that get's created at initialisation time if not already provided.
  ///
  public init(tree: OrderedDictionary<String, Any>, persistentID uuid: UUID = UUID()) throws
  where FileType == File<Contents>
  {
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

  /// Create an folder item from the given file wrappers.
  ///
  /// - Parameters:
  ///   - fileWrappers: The file wrappers representing the folder's children.
  ///   - persistentIDMap: Contains the available persistent ids for this folder and its children. If the map is not
  ///       available, new ids are generated.
  ///
  public init(fileWrappers: [String: FileWrapper], persistentIDMap fileMap: FileIDMap?) throws
  where FileType == File<Contents>
  {
    let children = try fileWrappers.map {
      (key: String, value: FileWrapper) in
      (key, try FileOrFolder<FileType, Contents>(fileWrapper: value, persistentIDMap: fileMap?.children[key])) },
      sortedChildren = children.sorted(by: { (lhs, rhs) in lhs.0 < rhs.0 })
    self.init(children: OrderedDictionary(uniqueKeysWithValues: sortedChildren), persistentID: fileMap?.id ?? UUID())
  }

  /// Yield a proxy version of the current (non-proxy) folder within the given file tree.
  ///
  public func proxy(within fileTree: FileTree<Contents>) -> Folder<File<Contents>.Proxy, Contents>
  where FileType == File<Contents>
  {
    // Add file paths for all direct children.
    for child in children { fileTree.addFilePath(of: child.value.id, named: child.key, within: id) }

    return Folder<File<Contents>.Proxy, Contents>(children: children.mapValues{ $0.proxy(within: fileTree) },
                                                  persistentID: id,
                                                  within: fileTree)
  }
}


// MARK: Operations for folders of proxy files

extension Folder {

  /// Snapshot a fgolder of proxy files into a folder of full files.
  ///
  public func snapshot() throws -> Folder<File<Contents>, Contents>
  where FileType == File<Contents>.Proxy
  {
    return Folder<File<Contents>, Contents>(children: try children.mapValues{ try $0.snapshot() }, persistentID: id)
  }
}


// MARK: Type aliases

/// Folder cintaining full files.
///
public typealias FullFolder<Contents: FileContents> = Folder<File<Contents>, Contents>

/// Folder containing file proxies.
/// 
public typealias ProxyFolder<Contents: FileContents> = Folder<File<Contents>.Proxy, Contents>
