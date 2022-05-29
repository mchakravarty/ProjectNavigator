//
//  FileNavigator.swift
//
//
//  Created by Manuel M T Chakravarty on 28/04/2022.
//
//  A file navigator enables the navigation of a file tree in a navigation view.
//
//  We have to supply the label view builders and context menu view builders separately, because attaching a context
//  menu to a `NavigationLink`s label doesn't work on macOS. (The context menu needs to be attached to the
//  `NavigationLink` in its entirety.)

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

/// Builds a file label view from the file's name and the file.
///
public typealias FileLabelBuilder<Payload: FileContents, FileLabelView: View>
  = (String, File<Payload>) -> FileLabelView

/// Builds a folder label view from the folder's name and the folder.
///
public typealias FolderLabelBuilder<Payload: FileContents, FolderLabelView: View>
  = (String, Folder<Payload>) -> FolderLabelView

/// Builds a file label context menu from the file's name, a binding to the file, and its parent (if it got one).
///
public typealias FileMenuBuilder<Payload: FileContents, FileMenuView: View>
  = (String, Binding<File<Payload>>, Binding<Folder<Payload>?>) -> FileMenuView

/// Builds a folder label context menu from the folders's name, a binding to the folder, and its parent (if it got
/// one).
///
public typealias FolderMenuBuilder<Payload: FileContents, FolderMenuView: View>
  = (String, Binding<Folder<Payload>>, Binding<Folder<Payload>?>) -> FolderMenuView

/// Builds a target view for a file target from a binding to the file.
///
public typealias TargetBuilder<Payload: FileContents, PayloadView: View>
  = (Binding<File<Payload>>) -> PayloadView

// Represents a file tree in a navigation view.
//
public struct FileNavigator<Payload: FileContents,
                            FileLabelView: View,
                            FolderLabelView: View,
                            FileMenuView: View,
                            FolderMenuView: View,
                            PayloadView: View>: View {
  @Binding var item:       FileOrFolder<Payload>
  @Binding var parent:     Folder<Payload>?
  @Binding var expansions: WrappedUUIDSet
  @Binding var selection:  FileOrFolder.ID?

  let name:        String
  let fileLabel:   FileLabelBuilder<Payload, FileLabelView>
  let folderLabel: FolderLabelBuilder<Payload, FolderLabelView>
  let fileMenu:    FileMenuBuilder<Payload, FileMenuView>
  let folderMenu:  FolderMenuBuilder<Payload, FolderMenuView>
  let target:      TargetBuilder<Payload, PayloadView>

  // TODO: We also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - item: The file item whose hierachy is being navigated.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - expansion: The set of currently expanded folders in the hierachy.
  ///   - selection: The currently selected file, if any.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///   - fileMenu: A view builder to produce the context menu for a file label.
  ///   - folderMenu: A view builder to produce the context menu for a folder label.
  ///
  public init<S: StringProtocol>(name: S,
                                 item: Binding<FileOrFolder<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 expansions: Binding<WrappedUUIDSet>,
                                 selection: Binding<FileOrFolder.ID?>,
                                 @ViewBuilder target: @escaping TargetBuilder<Payload, PayloadView>,
                                 @ViewBuilder fileLabel: @escaping FileLabelBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping FolderLabelBuilder<Payload, FolderLabelView>,
                                 @ViewBuilder fileMenu: @escaping FileMenuBuilder<Payload, FileMenuView>,
                                 @ViewBuilder folderMenu: @escaping FolderMenuBuilder<Payload, FolderMenuView>)
  {
    self._item       = item
    self._parent     = parent
    self._expansions = expansions
    self._selection  = selection
    self.name        = String(name)
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
    self.fileMenu    = fileMenu
    self.folderMenu  = folderMenu
    self.target      = target
  }

  public var body: some View {

    SwitchFileOrFolder(fileOrFolder: $item) { $file in

      // FIXME: We need to use `AnyView` here as the compiler otherwise crashes...
      AnyView(FileNavigatorFile(name: name,
                                file: $file,
                                parent: $parent,
                                selection: $selection,
                                target: target,
                                fileLabel: fileLabel,
                                folderLabel: folderLabel,
                                fileMenu: fileMenu,
                                folderMenu: folderMenu))

    } folderCase: { $folder in

      // FIXME: We need to use `AnyView` here as the compiler otherwise crashes...
      AnyView(FileNavigatorFolder(name: name,
                                  folder: $folder,
                                  parent: $parent,
                                  expansions: $expansions,
                                  selection: $selection,
                                  target: target,
                                  fileLabel: fileLabel,
                                  folderLabel: folderLabel,
                                  fileMenu: fileMenu,
                                  folderMenu: folderMenu))

    }
  }
}

// Represents a single file in a navigation view.
//
public struct FileNavigatorFile<Payload: FileContents,
                                FileLabelView: View,
                                FolderLabelView: View,
                                FileMenuView: View,
                                FolderMenuView: View,
                                PayloadView: View>: View {
  @Binding var file:      File<Payload>
  @Binding var parent:    Folder<Payload>?
  @Binding var selection: FileOrFolder.ID?

  let name:        String
  let fileLabel:   FileLabelBuilder<Payload, FileLabelView>
  let folderLabel: FolderLabelBuilder<Payload, FolderLabelView>
  let fileMenu:    FileMenuBuilder<Payload, FileMenuView>
  let folderMenu:  FolderMenuBuilder<Payload, FolderMenuView>
  let target:      (Binding<File<Payload>>) -> PayloadView

  // TODO: We probably also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigation link for a single file. The link needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - file: The file being represented.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - selection: The currently selected file, if any.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 file: Binding<File<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 selection: Binding<FileOrFolder.ID?>,
                                 @ViewBuilder target: @escaping (Binding<File<Payload>>) -> PayloadView,
                                 @ViewBuilder fileLabel: @escaping FileLabelBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping FolderLabelBuilder<Payload, FolderLabelView>,
                                 @ViewBuilder fileMenu: @escaping FileMenuBuilder<Payload, FileMenuView>,
                                 @ViewBuilder folderMenu: @escaping FolderMenuBuilder<Payload, FolderMenuView>)
  {
    self._file       = file
    self._parent     = parent
    self._selection  = selection
    self.name        = String(name)
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
    self.fileMenu    = fileMenu
    self.folderMenu  = folderMenu
    self.target      = target
  }

  public var body: some View {

    NavigationLink(tag: file.id, selection: $selection, destination: { target($file) }) { fileLabel(name, file) }
      .contextMenu{ fileMenu(name, $file, $parent) }
  }
}

public struct FileNavigatorFolder<Payload: FileContents,
                                  FileLabelView: View,
                                  FolderLabelView: View,
                                  FileMenuView: View,
                                  FolderMenuView: View,
                                  PayloadView: View>: View {
  @Binding var folder:     Folder<Payload>
  @Binding var parent:     Folder<Payload>?
  @Binding var expansions: WrappedUUIDSet
  @Binding var selection:  FileOrFolder.ID?

  let name:        String
  let fileLabel:   FileLabelBuilder<Payload, FileLabelView>
  let folderLabel: FolderLabelBuilder<Payload, FolderLabelView>
  let fileMenu:    FileMenuBuilder<Payload, FileMenuView>
  let folderMenu:  FolderMenuBuilder<Payload, FolderMenuView>
  let target:      (Binding<File<Payload>>) -> PayloadView

  @Environment(\.navigatorFilter) var navigatorFilter: (String) -> Bool

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the folder item.
  ///   - folder: The folder item whose hierachy is being navigated.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - expansion: The set of currently expanded folders in the hierachy.
  ///   - selection: The currently selected file, if any.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 folder: Binding<Folder<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 expansions: Binding<WrappedUUIDSet>,
                                 selection: Binding<FileOrFolder.ID?>,
                                 @ViewBuilder target: @escaping (Binding<File<Payload>>) -> PayloadView,
                                 @ViewBuilder fileLabel: @escaping FileLabelBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping FolderLabelBuilder<Payload, FolderLabelView>,
                                 @ViewBuilder fileMenu: @escaping FileMenuBuilder<Payload, FileMenuView>,
                                 @ViewBuilder folderMenu: @escaping FolderMenuBuilder<Payload, FolderMenuView>)
  {
    self._folder     = folder
    self._parent     = parent
    self._expansions = expansions
    self._selection  = selection
    self.name        = String(name)
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
    self.fileMenu    = fileMenu
    self.folderMenu  = folderMenu
    self.target      = target
  }

  public var body: some View {

    DisclosureGroup(isExpanded: $expansions[folder.id]) {

      ForEach(folder.children.elements.filter{ navigatorFilter($0.key) }, id: \.value.id) { keyValue in

        // FIXME: This is not nice...
        let i = folder.children.keys.firstIndex(of: keyValue.key)!
        FileNavigator(name: keyValue.key,
                      item: $folder.children.values[i],
                      parent: Binding($folder),
                      expansions: $expansions,
                      selection: $selection,
                      target: target,
                      fileLabel: fileLabel,
                      folderLabel: folderLabel,
                      fileMenu: fileMenu,
                      folderMenu: folderMenu)

      }

    } label: {

      folderLabel(name, folder)
        .contextMenu{ folderMenu(name, $folder, $parent) }

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
                    parent: .constant(nil),
                    expansions: $expansions,
                    selection: $selection,
                    target: { $file in Text(file.contents.text) },
                    fileLabel: { name, _item in Text(name) },
                    folderLabel: { name, _item in Text(name) },
                    fileMenu: { _, _, _ in },
                    folderMenu: { _, _, _ in })
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
