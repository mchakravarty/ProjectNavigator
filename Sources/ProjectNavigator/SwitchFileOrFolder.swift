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
public struct SwitchFileOrFolder<Contents: FileContents, FileContent: View, FolderContent: View>: View {
  @Binding public var fileOrFolder: ProxyFileOrFolder<Contents>

  public let fileCase:   (File<Contents>.Proxy) -> FileContent
  public let folderCase: (Binding<ProxyFolder<Contents>>) -> FolderContent

  /// Dispatch subviews on a dynamic file or folder choice.
  ///
  /// - Parameters:
  ///   - fileOrFolder: A file or folder binding.
  ///   - fileCase: Subview for the file case, receiving a file proxy.
  ///   - folderCase: Subview for the folder case, binding the folder contents.
  ///
  public init(fileOrFolder: Binding<ProxyFileOrFolder<Contents>>,
              fileCase: @escaping (File<Contents>.Proxy) -> FileContent,
              folderCase: @escaping (Binding<ProxyFolder<Contents>>) -> FolderContent)
  {
    self._fileOrFolder = fileOrFolder
    self.fileCase      = fileCase
    self.folderCase    = folderCase
  }

  public var body: some View {
    switch fileOrFolder {

    case .file(let proxy):
      fileCase(proxy)

    case .folder(let folder):
      let folderBinding = Binding { return folder } set: { fileOrFolder = .folder($0) }
      folderCase(folderBinding)

    }
  }
}
