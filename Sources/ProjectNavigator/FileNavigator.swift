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
// MARK: View model

/// This class captures a file navigator's view state.
///
public final class FileNavigatorViewModel<Contents: FileContents>: ObservableObject {

  public struct EditedLabel {
    public var id:   UUID
    public var text: String
  }

  /// Set of `UUID`s of all expanded folders.
  ///
  @Published public var expansions: WrappedUUIDSet

  /// The `UUID` of the selected file, if any.
  ///
  @Published public var selection: FileOrFolder.ID?

  /// The `UUID` and current string of the edited file or folder label, if any.
  ///
  @Published public var editedLabel: EditedLabel?

  /// Caches bindings to all selectable files by their uuid.
  ///
  private var fileMap: [UUID: Binding<File<Contents>>] = [:]

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
        self?.editedLabel = FileNavigatorViewModel.EditedLabel(id: id, text: newText)

      } else {

        // If this label is being edited, the editing has ended now
        if thisLabelIsBeingEdited { self?.editedLabel = nil }

      }
    }
  }

  /// Register the given file as selectable.
  ///
  /// - Parameter file: Binding of the file that can be selected.
  ///
  func register(file: Binding<File<Contents>>) {
    fileMap[file.id] = file
  }

  /// Deregister the file whose UUID is given as selectable.
  ///
  /// - Parameter id: UUID of the file that can no longer be selected.
  ///
  func deregisterFile(for id: UUID) {
    _ = fileMap.removeValue(forKey: id)
  }

  /// Binding to the currently selected file, if any.
  ///
  public var selectedFile: Binding<File<Contents>>? { selection.flatMap{ fileMap[$0] } }
}

/// A cursor points to an item in the file tree.
///
public struct FileNavigatorCursor<Payload: FileContents> {

  /// The item's name.
  ///
  public let name: String

  /// Binding to the item's parent if any. (This is necessary as all changes to an item need to go through its parent.)
  ///
  public let parent: Binding<Folder<Payload>?>
}


// MARK: -
// MARK: Views

/// Builds a view for a file item, given the cursor for that item, a binding to an optional edited name, and a binding
/// to the file.
///
public typealias NavigatorFileViewBuilder<Payload: FileContents, NavigatorView: View>
  = (FileNavigatorCursor<Payload>, Binding<String?>, Binding<File<Payload>>) -> NavigatorView

/// Builds a view for an folder item, given the cursor for that item, a binding to an optional edited name, and a
/// binding to the file.
///
public typealias NavigatorFolderViewBuilder<Payload: FileContents, NavigatorView: View>
  = (FileNavigatorCursor<Payload>, Binding<String?>, Binding<Folder<Payload>>) -> NavigatorView

// Represents a file tree in a navigation view.
//
public struct FileNavigator<Payload: FileContents,
                            FileLabelView: View,
                            FolderLabelView: View>: View {
  @Binding var item:   FileOrFolder<Payload>
  @Binding var parent: Folder<Payload>?

  @ObservedObject var viewModel: FileNavigatorViewModel<Payload>

  let name:        String
  let fileLabel:   NavigatorFileViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorFolderViewBuilder<Payload, FolderLabelView>

  // TODO: We also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - item: The file item whose hierachy is being navigated.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewModel: This navigator's view model.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 item: Binding<FileOrFolder<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 viewModel: FileNavigatorViewModel<Payload>,
                                 @ViewBuilder fileLabel: @escaping NavigatorFileViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorFolderViewBuilder<Payload, FolderLabelView>)
  {
    self._item       = item
    self._parent     = parent
    self.name        = String(name)
    self.viewModel   = viewModel
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
  }

  public var body: some View {

    SwitchFileOrFolder(fileOrFolder: $item) { $file in

      FileNavigatorFile(name: name,
                        file: $file,
                        parent: $parent,
                        viewModel: viewModel,
                        fileLabel: fileLabel,
                        folderLabel: folderLabel)

    } folderCase: { $folder in

      FileNavigatorFolder(name: name,
                          folder: $folder,
                          parent: $parent,
                          viewModel: viewModel,
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
  @Binding var file:   File<Payload>
  @Binding var parent: Folder<Payload>?

  @ObservedObject var viewModel: FileNavigatorViewModel<Payload>

  let name:        String
  let fileLabel:   NavigatorFileViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorFolderViewBuilder<Payload, FolderLabelView>

  // TODO: We probably also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigation link for a single file. The link needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - file: The file being represented.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewModel: This navigator's view model.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 file: Binding<File<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 viewModel: FileNavigatorViewModel<Payload>,
                                 @ViewBuilder fileLabel: @escaping NavigatorFileViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorFolderViewBuilder<Payload, FolderLabelView>)
  {
    self._file       = file
    self._parent     = parent
    self.name        = String(name)
    self.viewModel   = viewModel
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
  }

  public var body: some View {

    let cursor            = FileNavigatorCursor(name: name, parent: $parent),
        editedTextBinding = viewModel.editedText(for: file.id)

    fileLabel(cursor, editedTextBinding, $file)
    .onAppear{ viewModel.register(file: $file) }
    .onDisappear{ viewModel.deregisterFile(for: file.id) }
  }
}

public struct FileNavigatorFolder<Payload: FileContents,
                                  FileLabelView: View,
                                  FolderLabelView: View>: View {
  @Binding var folder: Folder<Payload>
  @Binding var parent: Folder<Payload>?

  @ObservedObject var viewModel: FileNavigatorViewModel<Payload>

  let name:        String
  let fileLabel:   NavigatorFileViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorFolderViewBuilder<Payload, FolderLabelView>

  @Environment(\.navigatorFilter) var navigatorFilter: (String) -> Bool

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the folder item.
  ///   - folder: The folder item whose hierachy is being navigated.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewModel: This navigator's view model.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 folder: Binding<Folder<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 viewModel: FileNavigatorViewModel<Payload>,
                                 @ViewBuilder fileLabel: @escaping NavigatorFileViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorFolderViewBuilder<Payload, FolderLabelView>)
  {
    self._folder     = folder
    self._parent     = parent
    self.name        = String(name)
    self.viewModel   = viewModel
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
  }

  public var body: some View {

    DisclosureGroup(isExpanded: $viewModel.expansions[folder.id]) {

      ForEach(folder.children.elements.filter{ navigatorFilter($0.key) }, id: \.value.id) { keyValue in

        // FIXME: This is not nice...
        let i = folder.children.keys.firstIndex(of: keyValue.key)!
        FileNavigator(name: keyValue.key,
                      item: $folder.children.values[i],
                      parent: Binding($folder),
                      viewModel: viewModel,
                      fileLabel: fileLabel,
                      folderLabel: folderLabel)

      }

    } label: {

      let cursor            = FileNavigatorCursor(name: name, parent: $parent),
          editedTextBinding = viewModel.editedText(for: folder.id)

      folderLabel(cursor, editedTextBinding, $folder)

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
    let item: FileOrFolder<Payload>

    @ObservedObject var viewModel = FileNavigatorViewModel<Payload>(expansions: WrappedUUIDSet(),
                                                                    selection: nil,
                                                                    editedLabel: nil)
    var body: some View {

      NavigationSplitView {
        List(selection: $viewModel.selection) {

          FileNavigator(name: "Root",
                        item: .constant(item),
                        parent: .constant(nil),
                        viewModel: viewModel,
                        fileLabel: { cursor, _editing, _ in Text(cursor.name) },
                        folderLabel: { cursor, _editing, _ in Text(cursor.name) })

        }
        .navigationTitle("Entries")

      } detail: {

        if let file = viewModel.selectedFile {

          Text(file.contents.text.wrappedValue)

        } else {

          Text("Select a file")

        }
      }
    }
  }

  static var previews: some View {
    let item = FileOrFolder<Payload>(folder: try! Folder(tree: try! treeToPayload(tree: _tree)))

    Container(item: item)
  }
}

struct FileNavigatorEditLabel_Previews: PreviewProvider {

  struct Container: View {
    @State var item  = FileOrFolder<Payload>(folder: try! Folder(tree: try! treeToPayload(tree: _tree)))

    @ObservedObject var viewModel = FileNavigatorViewModel<Payload>(expansions: WrappedUUIDSet(),
                                                                    selection: nil,
                                                                    editedLabel: nil)

    var body: some View {

      NavigationSplitView {
        List(selection: $viewModel.selection) {

          FileNavigator(name: "Root",
                        item: $item,
                        parent: .constant(nil),
                        viewModel: viewModel,
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

        if let file = viewModel.selectedFile {

          Text(file.contents.text.wrappedValue)

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
