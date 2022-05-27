//
//  SwitchFileOrFolder.swift
//  
//
//  Created by Manuel M T Chakravarty on 06/05/2022.
//

import SwiftUI

import Files


/// Dispatch on a file or folder choice of a binding, such that the cases receive bindings of the respective component.
///
public struct SwitchFileOrFolder<Contents: FileContents, Content: View>: View {
  @Binding public var fileOrFolder: FileOrFolder<Contents>

  public let fileCase:   (Binding<File<Contents>>) -> Content
  public let folderCase: (Binding<Folder<Contents>>) -> Content

  /// Dispatch subviews on a dynamic file or folder choice.
  ///
  /// - Parameters:
  ///   - fileOrFolder: A file or folder binding.
  ///   - fileCase: Subview for the file case, binding the file contents.
  ///   - folderCase: Subview for the folder case, binding teh folder contents.
  ///
  public init(fileOrFolder: Binding<FileOrFolder<Contents>>,
              fileCase: @escaping (Binding<File<Contents>>) -> Content,
              folderCase: @escaping (Binding<Folder<Contents>>) -> Content)
  {
    self._fileOrFolder = fileOrFolder
    self.fileCase      = fileCase
    self.folderCase    = folderCase
  }

  public var body: some View {
    switch fileOrFolder {

    case .file(let file):
      let fileBinding = Binding { return file } set: { fileOrFolder = .file($0) }
      fileCase(fileBinding)

    case .folder(let folder):
      let folderBinding = Binding { return folder } set: { fileOrFolder = .folder($0) }
      folderCase(folderBinding)

    }
  }
}
