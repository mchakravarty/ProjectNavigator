//
//  NavigatorDemoDocument.swift
//  Shared
//
//  Created by Manuel M T Chakravarty on 16/05/2022.
//
//  The persistent representation of our documents is a nested folder structure containing text files and possibly also
//  a file map.

import SwiftUI
import UniformTypeIdentifiers

import Files


private let fileMapName = ".FileMap.plist"

extension UTType {
  static var textBundle: UTType {
    UTType(exportedAs: "org.justtesting.text-bundle")
  }
}

struct Payload: FileContents {

  /// Text in a file if its a text file containing UTF-8.
  ///
  var text: String? {
    didSet {
      backingData = nil
    }
  }

  /// Data in a file unless `text` has been updated and not yet marshalled back to `Data` again.
  ///
  private var backingData: Data?

  init(text: String) {
    self.text = text
  }

  /// Files ending with a text file extension are converted to text if they conform to UTF-8.
  ///
  init(name: String, data: Data) throws {
    self.backingData = data
    if UTType(filenameExtension: (name as NSString).pathExtension, conformingTo: .text) != nil,
       let text = String(data: data, encoding: .utf8) {
      self.text = text
    }
  }

  func data() throws -> Data {
    if let data = backingData { return data }
    else if let data = text?.data(using: .utf8) { return data }
    else { throw CocoaError(.formatting) }
  }

  /// Update backing data if necessary.
  ///
  mutating func flush() {
    if backingData == nil,
       let data = text?.data(using: .utf8)
    {
      backingData = data
    }
  }
}

final class NavigatorDemoDocument: ReferenceFileDocument {
  typealias Snapshot = Folder<Payload>

  @Published var texts: Folder<Payload>

  init(text: String = "Beautiful text!") {
    self.texts = Folder(children: ["MyText.txt": FileOrFolder(file: File(contents: Payload(text: text)))])
  }

  static var readableContentTypes: [UTType] { [.textBundle] }

  init(configuration: ReadConfiguration) throws {
    guard configuration.file.isDirectory,
          let fileWrappers = configuration.file.fileWrappers
    else { throw CocoaError(.fileReadCorruptFile) }

    // Get the persistent file ids if available.
    let fileMap: FileIDMap?
    if let fileMapFileWrapper = fileWrappers[fileMapName],
       fileMapFileWrapper.isRegularFile,
       let fileMapData = fileMapFileWrapper.regularFileContents
    {

      let decoder = PropertyListDecoder()
      fileMap = try? decoder.decode(FileIDMap.self, from: fileMapData)

    } else { fileMap = nil }

    // Slurp in the tree of folders.
    texts = try Folder<Payload>(fileWrappers: fileWrappers, persistentIDMap: fileMap)
  }

  func snapshot(contentType: UTType) throws -> Snapshot {
    guard contentType == .textBundle else { throw CocoaError(.fileWriteUnknown) }

    try texts.flush()
    return texts
  }

  func fileWrapper(snapshot: Snapshot, configuration: WriteConfiguration) throws -> FileWrapper {
    return try snapshot.fileWrapper()
  }
}
