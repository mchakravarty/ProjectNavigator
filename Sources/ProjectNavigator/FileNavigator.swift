//
//  FileNavigator.swift
//
//
//  Created by Manuel M T Chakravarty on 28/04/2022.
//

import SwiftUI

import Files


public struct FileNavigator<Payload: FileContents, LabelView: View, PayloadView: View>: View {
  @Binding var root: FileOrFolder<Payload>

  let name:   String
  let label:  (String, FileOrFolder<Payload>) -> LabelView
  let target: (File<Payload>) -> PayloadView

  // TODO: We also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the root item.
  ///   - root: The file item whose hierachy is being navigated.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - label: A view builder to produce a label for a file or folder.
  ///   
  public init<S: StringProtocol>(name: S,
                                 root: Binding<FileOrFolder<Payload>>,
                                 @ViewBuilder target: @escaping (File<Payload>) -> PayloadView,
                                 @ViewBuilder label: @escaping (String, FileOrFolder<Payload>) -> LabelView)
  {
    self._root  = root
    self.name   = String(name)
    self.label  = label
    self.target = target
  }

  public var body: some View {
    Text("")
  }
}
