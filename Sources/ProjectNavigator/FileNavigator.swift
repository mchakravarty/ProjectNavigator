//
//  FileNavigator.swift
//
//
//  Created by Manuel M T Chakravarty on 28/04/2022.
//
//  A file navigator enables the navigation of a file tree in a navigation view.

import UniformTypeIdentifiers
import Observation
import SwiftUI
import OrderedCollections

import Files


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
// MARK: View state

/// This class captures a file navigator's view state.
///
@Observable
public final class FileNavigatorViewState<Payload: FileContents> {

  /// The `UUID` and name of a label that is being edited.
  ///
  public struct EditedLabel {
    public var id:   UUID
    public var text: String
  }

  /// Set of `UUID`s of all expanded folders.
  ///
  public var expansions: WrappedUUIDSet

  /// The `UUID` of the selected file, if any.
  ///
  public var selection: FileOrFolder.ID?
  
  /// Provided that there is a unique selection, if it is a folder, the folder itself is the dominant folder.
  /// If a unique file is selected, its parent folder constitutes the dominant folder. Otherwise, we don't have a
  /// dominant folder.
  ///
  public internal(set) var dominantFolder: Binding<ProxyFolder<Payload>?>? = nil

  /// The `UUID` and current string of the edited file or folder label, if any.
  ///
  public var editedLabel: EditedLabel?

  /// A file navigator's view state.
  ///
  /// - Parameters:
  ///   - expansions: The `UUID`s of all expanded folders.
  ///   - selection: The `UUID` of the selected file, if any.
  ///   - editedLabel: The `UUID` and current string of the edited file or folder label, if any.
  ///
  public init(expansions: WrappedUUIDSet = WrappedUUIDSet(), 
              selection: FileOrFolder.ID? = nil,
              editedLabel: EditedLabel? = nil)
  {
    self.expansions  = expansions
    self.selection   = selection
    self.editedLabel = editedLabel
  }

  /// Projects an edited text binding for a given UUID out of our `editedLabel` property.
  ///
  /// - Parameter id: The id whose item's label ought to be projected to handle the edited state.
  /// - Returns: A binding to the projected edited label text.
  ///
  /// If a label associated with the item identified by `id` is edited, the resulting binding contains the current
  /// value of the edited text.
  ///
  func editedText(for id: UUID) -> Binding<String?> {
    let thisLabelIsBeingEdited = editedLabel?.id == id,
        editedText             = thisLabelIsBeingEdited ? editedLabel?.text : nil

    return Binding { editedText } set: { [weak self] optionalNewText in

      if let newText = optionalNewText {

        // This label is being edited and the edited text is being updated
        self?.editedLabel = FileNavigatorViewState.EditedLabel(id: id, text: newText)

      } else {

        // If this label is being edited, the editing has ended now
        if thisLabelIsBeingEdited { self?.editedLabel = nil }

      }
    }
  }
}

/// A cursor points to an item in the file tree.
///
public struct FileNavigatorCursor<Payload: FileContents> {

  /// The item's name.
  ///
  public let name: String

  /// Binding to the item's parent if any. (This is necessary as all changes to an item need to go through its parent.)
  ///
  public let parent: Binding<ProxyFolder<Payload>?>
}


// MARK: -
// MARK: Views

/// Builds a view for a file item, given the cursor for that item, a binding to an optional edited name, and the proxy
/// for the file.
///
public typealias NavigatorFileViewBuilder<Payload: FileContents, NavigatorView: View>
  = (FileNavigatorCursor<Payload>, Binding<String?>, File<Payload>.Proxy) -> NavigatorView

/// Builds a view for an folder item, given the cursor for that item, a binding to an optional edited name, and a
/// binding to folder (of proxies).
///
public typealias NavigatorFolderViewBuilder<Payload: FileContents, NavigatorView: View>
  = (FileNavigatorCursor<Payload>, Binding<String?>, Binding<ProxyFolder<Payload>>) -> NavigatorView

// Represents a file tree in a navigation view.
//
public struct FileNavigator<Payload: FileContents,
                            FileLabelView: View,
                            FolderLabelView: View>: View {
  @Binding var item:   ProxyFileOrFolder<Payload>
  @Binding var parent: ProxyFolder<Payload>?

  let viewState: FileNavigatorViewState<Payload>

  let name:        String
  let fileLabel:   NavigatorFileViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorFolderViewBuilder<Payload, FolderLabelView>

  // TODO: We also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationSplitView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - item: The file item whose hierachy is being navigated.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewState: This navigator's view state.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 item: Binding<ProxyFileOrFolder<Payload>>,
                                 parent: Binding<ProxyFolder<Payload>?>,
                                 viewState: FileNavigatorViewState<Payload>,
                                 @ViewBuilder fileLabel: @escaping NavigatorFileViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorFolderViewBuilder<Payload, FolderLabelView>)
  {
    self._item       = item
    self._parent     = parent
    self.name        = String(name)
    self.viewState   = viewState
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
  }

  public var body: some View {

    SwitchFileOrFolder(fileOrFolder: $item) { file in

      FileNavigatorFile(name: name,
                        proxy: file,
                        parent: $parent,
                        viewState: viewState,
                        fileLabel: fileLabel,
                        folderLabel: folderLabel)

    } folderCase: { $folder in

      FileNavigatorFolder(name: name,
                          folder: $folder,
                          parent: $parent,
                          viewState: viewState,
                          fileLabel: fileLabel,
                          folderLabel: folderLabel)

    }
  }
}

// Represents a single file in a navigation view.
//
public struct FileNavigatorFile<Payload: FileContents,
                                FileLabelView: View,
                                FolderLabelView: View>: View {
  let proxy: File<Payload>.Proxy

  @Binding var parent: ProxyFolder<Payload>?

  var viewState: FileNavigatorViewState<Payload>

  let name:        String
  let fileLabel:   NavigatorFileViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorFolderViewBuilder<Payload, FolderLabelView>

  // TODO: We probably also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigation link for a single file. The link needs to be contained in a `NavigationSplitView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file.
  ///   - proxy: The proxy of the file being represented.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewState: This navigator's view state.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 proxy: File<Payload>.Proxy,
                                 parent: Binding<ProxyFolder<Payload>?>,
                                 viewState: FileNavigatorViewState<Payload>,
                                 @ViewBuilder fileLabel: @escaping NavigatorFileViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorFolderViewBuilder<Payload, FolderLabelView>)
  {
    self.proxy       = proxy
    self._parent     = parent
    self.name        = String(name)
    self.viewState   = viewState
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
  }

  public var body: some View {

    let cursor            = FileNavigatorCursor(name: name, parent: $parent),
        editedTextBinding = viewState.editedText(for: proxy.id)

    // NB: Need an explicit link here to ensure that a single toplevel file is selectable, too.
    NavigationLink(value: proxy.id) { fileLabel(cursor, editedTextBinding, proxy) }
      .onChange(of: viewState.selection) {
        if viewState.selection == proxy.id {
          viewState.dominantFolder = cursor.parent
        }
      }
  }
}

/// Represents a folder in a navigation view.
///
public struct FileNavigatorFolder<Payload: FileContents,
                                  FileLabelView: View,
                                  FolderLabelView: View>: View {
  @Binding var folder: ProxyFolder<Payload>
  @Binding var parent: ProxyFolder<Payload>?

  @Bindable var viewState: FileNavigatorViewState<Payload>

  let name:        String
  let fileLabel:   NavigatorFileViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorFolderViewBuilder<Payload, FolderLabelView>

  @Environment(\.navigatorFilter) var navigatorFilter: (String) -> Bool

  /// Creates a navigator for the given folder. The navigator needs to be contained in a `NavigationSplitView`.
  ///
  /// - Parameters:
  ///   - name: The name of the folder item.
  ///   - folder: The folder item whose hierachy is being navigated.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewState: This navigator's view state.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 folder: Binding<ProxyFolder<Payload>>,
                                 parent: Binding<ProxyFolder<Payload>?>,
                                 viewState: FileNavigatorViewState<Payload>,
                                 @ViewBuilder fileLabel: @escaping NavigatorFileViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorFolderViewBuilder<Payload, FolderLabelView>)
  {
    self._folder     = folder
    self._parent     = parent
    self.name        = String(name)
    self.viewState   = viewState
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
  }

  public var body: some View {

    DisclosureGroup(isExpanded: $viewState.expansions[folder.id]) {

      ForEach(folder.children.elements.filter{ navigatorFilter($0.key) }, id: \.value.id) { keyValue in

        // FIXME: This is not nice...
        let i = folder.children.keys.firstIndex(of: keyValue.key)!
        FileNavigator(name: keyValue.key,
                      item: $folder.children.values[i],
                      parent: Binding($folder),
                      viewState: viewState,
                      fileLabel: fileLabel,
                      folderLabel: folderLabel)

      }

    } label: {

      let cursor            = FileNavigatorCursor(name: name, parent: $parent),
          editedTextBinding = viewState.editedText(for: folder.id)

      // NB: Need an explicit link here to ensure that the toplevel folder is selectable, too.
      NavigationLink(value: folder.id) { folderLabel(cursor, editedTextBinding, $folder) }
        .onChange(of: viewState.selection) {
          if viewState.selection == folder.id {
            viewState.dominantFolder = Binding($folder)
          }
        }

    }
  }
}


// MARK: -
// MARK: Preview

import _FilesTestSupport

let _tree = ["Alice"  : "Hello",
             "Bob"    : "Howdy",
             "More"   : ["Sun"  : "Light",
                         "Moon" : "Twilight"] as OrderedDictionary<String, Any>,
             "Charlie": "Dag"] as OrderedDictionary<String, Any>

struct FileNavigator_Previews: PreviewProvider {

  struct Container: View {
    let fileTree: FileTree<Payload>

    @Bindable var viewState = FileNavigatorViewState<Payload>(expansions: WrappedUUIDSet(),
                                                              selection: nil,
                                                              editedLabel: nil)

    var body: some View {

      NavigationSplitView {
        List(selection: $viewState.selection) {

          FileNavigator(name: "Root",
                        item: .constant(fileTree.root),
                        parent: .constant(nil),
                        viewState: viewState,
                        fileLabel: { cursor, _editing, _ in Text(cursor.name) },
                        folderLabel: { cursor, _editing, _ in Text(cursor.name) })

        }
        .navigationTitle("Entries")

      } detail: {

        if let uuid = viewState.selection,
           let file = fileTree.proxy(for: uuid).file
        {

          Text(file.contents.text)

        } else {

          Text("Select a file")

        }
      }
    }
  }

  static var previews: some View {
    let item = FullFileOrFolder<Payload>(folder: try! Folder(tree: try! treeToPayload(tree: _tree)))

    Container(fileTree: FileTree(files: item))
  }
}

struct FileNavigatorEditLabel_Previews: PreviewProvider {

  struct Container: View {
    @State var fileTree
      = FileTree(files: FullFileOrFolder<Payload>(folder: try! Folder(tree: try! treeToPayload(tree: _tree))))

    @Bindable var viewState = FileNavigatorViewState<Payload>(expansions: WrappedUUIDSet(),
                                                              selection: nil,
                                                              editedLabel: nil)

    var body: some View {

      NavigationSplitView {
        List(selection: $viewState.selection) {

          FileNavigator(name: "Root",
                        item: $fileTree.root,
                        parent: .constant(nil),
                        viewState: viewState,
                        fileLabel: { cursor, $editedText, _ in
                                       EditableLabel(cursor.name,
                                                     systemImage: "doc.plaintext.fill",
                                                     editedText: $editedText)
                                         .onSubmit {
                                           if let newName = editedText {
                                             _ = cursor.parent.wrappedValue?.rename(name: cursor.name, to: newName)
                                             editedText = nil
                                           }
                                         }
                                         .contextMenu {
                                           Button {
                                             editedText = cursor.name
                                           } label: {
                                             Label("Change name", systemImage: "pencil")
                                           }
                                         }
                                    },
                        folderLabel: { cursor, $editedText, _ in
                                         EditableLabel(cursor.name, systemImage: "folder.fill", editedText: $editedText)
                                           .onSubmit {
                                             if let newName = editedText {
                                               _ = cursor.parent.wrappedValue?.rename(name: cursor.name, to: newName)
                                               editedText = nil
                                             }
                                           }
                                           .contextMenu {
                                             Button {
                                               editedText = cursor.name
                                             } label: {
                                               Label("Change name", systemImage: "pencil")
                                             }
                                           }
                                     })

        }
        .navigationTitle("Entries")

      } detail: {

        if let uuid = viewState.selection,
           let file = fileTree.proxy(for: uuid).file
        {

          Text(file.contents.text)

        } else {

          Text("Select a file")

        }
      }
    }
  }

  static var previews: some View {
    Container()
  }
}

struct FileNavigatorSingleFile_Previews: PreviewProvider {

  struct Container: View {
    let fileTree: FileTree<Payload>

    @Bindable var viewState = FileNavigatorViewState<Payload>(expansions: WrappedUUIDSet(),
                                                              selection: nil,
                                                              editedLabel: nil)
    var body: some View {

      NavigationSplitView {
        List(selection: $viewState.selection) {

          FileNavigator(name: "TheFile",
                        item: .constant(fileTree.root),
                        parent: .constant(nil),
                        viewState: viewState,
                        fileLabel: { cursor, _editing, _ in Text(cursor.name) },
                        folderLabel: { cursor, _editing, _ in Text(cursor.name) })

        }
        .navigationTitle("Entries")

      } detail: {

        if let uuid = viewState.selection,
           let file = fileTree.proxy(for: uuid).file
        {

          Text(file.contents.text)

        } else {

          Text("Select a file")

        }
      }
    }
  }

  static var previews: some View {
    let item = FullFileOrFolder(file: File<Payload>(contents: Payload(text: "Awesome contents")))

    Container(fileTree: FileTree(files: item))
  }
}
