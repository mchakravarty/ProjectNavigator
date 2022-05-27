//
//  FileNavigator.swift
//
//
//  Created by Manuel M T Chakravarty on 28/04/2022.
//
//  A file navigator enables the navigation of a file tree in a navigation view.

import SwiftUI
import OrderedCollections

import Files
import _FilesTestSupport


// MARK: -
// MARK: Navigator environment values

public struct NavigatorFilter: EnvironmentKey {
  public static let defaultValue: (String) -> Bool = { _ in true }
}

extension EnvironmentValues {

  /// An environment value containing a function that determines whether an item with the given name ought to displayed
  /// by the file navigator within a folder.
  ///
  public var navigatorFilter: (String) -> Bool {
    get { self[NavigatorFilter.self] }
    set { self[NavigatorFilter.self] = newValue }
  }
}

extension View {
  public func navigatorFilter(_ navigatorFilter: @escaping (String) -> Bool) -> some View {
    environment(\.navigatorFilter, navigatorFilter)
  }
}


// MARK: -
// MARK: Views

// Represents a file tree in a navigation view.
//
public struct FileNavigator<Payload: FileContents,
                            FileLabelView: View,
                            FolderLabelView: View,
                            PayloadView: View>: View {
  @Binding var item:       FileOrFolder<Payload>
  @Binding var expansions: WrappedUUIDSet
  @Binding var selection:  FileOrFolder.ID?

  let name:        String
  let fileLabel:   (String, Binding<File<Payload>>) -> FileLabelView
  let folderLabel: (String, Binding<Folder<Payload>>) -> FolderLabelView
  let target:      (Binding<File<Payload>>) -> PayloadView

  // TODO: We also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - item: The file item whose hierachy is being navigated.
  ///   - expansion: The set of currently expanded folders in the hierachy.
  ///   - selection: The currently selected file, if any.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 item: Binding<FileOrFolder<Payload>>,
                                 expansions: Binding<WrappedUUIDSet>,
                                 selection: Binding<FileOrFolder.ID?>,
                                 @ViewBuilder target: @escaping (Binding<File<Payload>>) -> PayloadView,
                                 @ViewBuilder fileLabel: @escaping (String, Binding<File<Payload>>) -> FileLabelView,
                                 @ViewBuilder folderLabel: @escaping (String, Binding<Folder<Payload>>) -> FolderLabelView)
  {
    self._item       = item
    self._expansions = expansions
    self._selection  = selection
    self.name        = String(name)
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
    self.target      = target
  }

  public var body: some View {

    SwitchFileOrFolder(fileOrFolder: $item) { $file in

      // FIXME: We need to use `AnyView` here as the compiler otherwise crashes...
      AnyView(FileNavigatorFile(name: name,
                                file: $file,
                                selection: $selection,
                                target: target,
                                fileLabel: fileLabel,
                                folderLabel: folderLabel))

    } folderCase: { $folder in

      // FIXME: We need to use `AnyView` here as the compiler otherwise crashes...
      AnyView(FileNavigatorFolder(name: name,
                                  folder: $folder,
                                  expansions: $expansions,
                                  selection: $selection,
                                  target: target,
                                  fileLabel: fileLabel,
                                  folderLabel: folderLabel))

    }
  }
}

// Represents a single file in a navigation view.
//
public struct FileNavigatorFile<Payload: FileContents,
                                FileLabelView: View,
                                FolderLabelView: View,
                                PayloadView: View>: View {
  @Binding var file:      File<Payload>
  @Binding var selection: FileOrFolder.ID?

  let name:        String
  let fileLabel:   (String, Binding<File<Payload>>) -> FileLabelView
  let folderLabel: (String, Binding<Folder<Payload>>) -> FolderLabelView
  let target:      (Binding<File<Payload>>) -> PayloadView

  // TODO: We probably also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigation link for a single file. The link needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - file: The file being represented.
  ///   - selection: The currently selected file, if any.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 file: Binding<File<Payload>>,
                                 selection: Binding<FileOrFolder.ID?>,
                                 @ViewBuilder target: @escaping (Binding<File<Payload>>) -> PayloadView,
                                 @ViewBuilder fileLabel: @escaping (String, Binding<File<Payload>>) -> FileLabelView,
                                 @ViewBuilder folderLabel: @escaping (String, Binding<Folder<Payload>>) -> FolderLabelView)
  {
    self._file       = file
    self._selection  = selection
    self.name        = String(name)
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
    self.target      = target
  }

  public var body: some View {
    NavigationLink(tag: file.id, selection: $selection, destination: { target($file) }) { fileLabel(name, $file) }
  }
}

public struct FileNavigatorFolder<Payload: FileContents,
                                  FileLabelView: View,
                                  FolderLabelView: View,
                                  PayloadView: View>: View {
  @Binding var folder:     Folder<Payload>
  @Binding var expansions: WrappedUUIDSet
  @Binding var selection:  FileOrFolder.ID?

  let name:        String
  let fileLabel:   (String, Binding<File<Payload>>) -> FileLabelView
  let folderLabel: (String, Binding<Folder<Payload>>) -> FolderLabelView
  let target:      (Binding<File<Payload>>) -> PayloadView

  @Environment(\.navigatorFilter) var navigatorFilter: (String) -> Bool

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the folder item.
  ///   - folder: The folder item whose hierachy is being navigated.
  ///   - expansion: The set of currently expanded folders in the hierachy.
  ///   - selection: The currently selected file, if any.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 folder: Binding<Folder<Payload>>,
                                 expansions: Binding<WrappedUUIDSet>,
                                 selection: Binding<FileOrFolder.ID?>,
                                 @ViewBuilder target: @escaping (Binding<File<Payload>>) -> PayloadView,
                                 @ViewBuilder fileLabel: @escaping (String, Binding<File<Payload>>) -> FileLabelView,
                                 @ViewBuilder folderLabel: @escaping (String, Binding<Folder<Payload>>) -> FolderLabelView)
  {
    self._folder     = folder
    self._expansions = expansions
    self._selection  = selection
    self.name        = String(name)
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
    self.target      = target
  }

  public var body: some View {

    DisclosureGroup(isExpanded: $expansions[folder.id]) {

      ForEach(folder.children.elements.filter{ navigatorFilter($0.key) }, id: \.value.id) { keyValue in

        // FIXME: This is not nice...
        let i = folder.children.keys.firstIndex(of: keyValue.key)!
        FileNavigator(name: keyValue.key,
                      item: $folder.children.values[i],
                      expansions: $expansions,
                      selection: $selection,
                      target: target,
                      fileLabel: fileLabel,
                      folderLabel: folderLabel)

      }

    } label: {
      folderLabel(name, $folder)
    }
  }
}


// MARK: -
// MARK: Preview

struct ContentView_Previews: PreviewProvider {
  struct Container: View {
    @State var expansions: WrappedUUIDSet = WrappedUUIDSet()
    @State var selection:  FileOrFolder.ID?

    var body: some View {

      let tree  = ["Alice"  : "Hello",
                   "Bob"    : "Howdy",
                   "More"   : ["Sun"  : "Light",
                               "Moon" : "Twilight"] as OrderedDictionary<String, Any>,
                   "Charlie": "Dag"] as OrderedDictionary<String, Any>,
          item  = FileOrFolder<Payload>(folder: try! Folder(tree: try! treeToPayload(tree: tree)))

      FileNavigator(name: "Root",
                    item: .constant(item),
                    expansions: $expansions,
                    selection: $selection,
                    target: { $file in Text(file.contents.text) },
                    fileLabel: { name, _item in Text(name) },
                    folderLabel: { name, _item in Text(name) })
    }
  }

  static var previews: some View {
    NavigationView {
      List {
        Container()
      }
      Text("Select an item")
    }
  }
}
