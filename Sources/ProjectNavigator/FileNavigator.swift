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
public final class FileNavigatorViewModel: ObservableObject {

  public struct EditedLabel {
    public var id:   UUID
    public var text: String
  }

  /// Set of `UUID`s of all expanded folders.
  ///
  @Published var expansions: WrappedUUIDSet

  /// The `UUID` of the selected file, if any.
  ///
  @Published var selection: FileOrFolder.ID?

  /// The `UUID` and current string of the edited file or folder label, if any.
  ///
  @Published var editedLabel: EditedLabel?

  /// A file navigator's view state.
  ///
  /// - Parameters:
  ///   - expansions: The `UUID`s of all expanded folders.
  ///   - selection: The `UUID` of the selected file, if any.
  ///   - editedLabel: The `UUID` and current string of the edited file or folder label, if any.
  ///
  public init(expansions: WrappedUUIDSet,
              selection: FileOrFolder.ID?,
              editedLabel: EditedLabel?)
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
}

/// A cursor points to an item in the file tree.
///
public struct FileNavigatorCursor<Payload: FileContents> {

  /// The item's name.
  ///
  public let name:   String

  /// Binding to the item's parent if any. (This is necessary as all changes to an item need to go through its parent.)
  ///
  public let parent: Binding<Folder<Payload>?>
}


// MARK: -
// MARK: Views

/// Builds a view for an item, given the cursor for that item and a binding to an optional edited name.
///
public typealias NavigatorViewBuilder<Payload: FileContents, NavigatorView: View>
  = (FileNavigatorCursor<Payload>, Binding<String?>) -> NavigatorView

/// Builds a target view for a file target from a binding to the file.
///
public typealias TargetViewBuilder<Payload: FileContents, PayloadView: View>
  = (Binding<File<Payload>>) -> PayloadView

// Represents a file tree in a navigation view.
//
public struct FileNavigator<Payload: FileContents,
                            FileLabelView: View,
                            FolderLabelView: View,
                            FileMenuView: View,
                            FolderMenuView: View,
                            PayloadView: View>: View {
  @Binding var item:   FileOrFolder<Payload>
  @Binding var parent: Folder<Payload>?

  @ObservedObject var viewModel: FileNavigatorViewModel

  let name:        String
  let fileLabel:   NavigatorViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorViewBuilder<Payload, FolderLabelView>
  let fileMenu:    NavigatorViewBuilder<Payload, FileMenuView>
  let folderMenu:  NavigatorViewBuilder<Payload, FolderMenuView>
  let target:      TargetViewBuilder<Payload, PayloadView>

  // TODO: We also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - item: The file item whose hierachy is being navigated.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewModel: The navigator's view model object.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///   - fileMenu: A view builder to produce the context menu for a file label.
  ///   - folderMenu: A view builder to produce the context menu for a folder label.
  ///
  public init<S: StringProtocol>(name: S,
                                 item: Binding<FileOrFolder<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 viewModel: FileNavigatorViewModel,
                                 @ViewBuilder target: @escaping TargetViewBuilder<Payload, PayloadView>,
                                 @ViewBuilder fileLabel: @escaping NavigatorViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorViewBuilder<Payload, FolderLabelView>,
                                 @ViewBuilder fileMenu: @escaping NavigatorViewBuilder<Payload, FileMenuView>,
                                 @ViewBuilder folderMenu: @escaping NavigatorViewBuilder<Payload, FolderMenuView>)
  {
    self._item       = item
    self._parent     = parent
    self.viewModel   = viewModel
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
                                viewModel: viewModel,
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
                                  viewModel: viewModel,
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
  @Binding var file:   File<Payload>
  @Binding var parent: Folder<Payload>?

  @ObservedObject var viewModel: FileNavigatorViewModel

  let name:        String
  let fileLabel:   NavigatorViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorViewBuilder<Payload, FolderLabelView>
  let fileMenu:    NavigatorViewBuilder<Payload, FileMenuView>
  let folderMenu:  NavigatorViewBuilder<Payload, FolderMenuView>
  let target:      TargetViewBuilder<Payload, PayloadView>

  // TODO: We probably also need a version of the initialiser that takes a `LocalizedStringKey`.

  /// Creates a navigation link for a single file. The link needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the file item.
  ///   - file: The file being represented.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewModel: The navigator's view model object.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 file: Binding<File<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 viewModel: FileNavigatorViewModel,
                                 @ViewBuilder target: @escaping TargetViewBuilder<Payload, PayloadView>,
                                 @ViewBuilder fileLabel: @escaping NavigatorViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorViewBuilder<Payload, FolderLabelView>,
                                 @ViewBuilder fileMenu: @escaping NavigatorViewBuilder<Payload, FileMenuView>,
                                 @ViewBuilder folderMenu: @escaping NavigatorViewBuilder<Payload, FolderMenuView>)
  {
    self._file       = file
    self._parent     = parent
    self.viewModel   = viewModel
    self.name        = String(name)
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
    self.fileMenu    = fileMenu
    self.folderMenu  = folderMenu
    self.target      = target
  }

  public var body: some View {

    let cursor            = FileNavigatorCursor(name: name, parent: $parent),
        editedTextBinding = viewModel.editedText(for: file.id)

    NavigationLink(tag: file.id, selection: $viewModel.selection, destination: { target($file) }) {
      fileLabel(cursor, editedTextBinding)
    }
    .contextMenu{ fileMenu(cursor, editedTextBinding) }
  }
}

public struct FileNavigatorFolder<Payload: FileContents,
                                  FileLabelView: View,
                                  FolderLabelView: View,
                                  FileMenuView: View,
                                  FolderMenuView: View,
                                  PayloadView: View>: View {
  @Binding var folder: Folder<Payload>
  @Binding var parent: Folder<Payload>?

  @ObservedObject var viewModel: FileNavigatorViewModel

  let name:        String
  let fileLabel:   NavigatorViewBuilder<Payload, FileLabelView>
  let folderLabel: NavigatorViewBuilder<Payload, FolderLabelView>
  let fileMenu:    NavigatorViewBuilder<Payload, FileMenuView>
  let folderMenu:  NavigatorViewBuilder<Payload, FolderMenuView>
  let target:      TargetViewBuilder<Payload, PayloadView>

  @Environment(\.navigatorFilter) var navigatorFilter: (String) -> Bool

  /// Creates a navigator for the given file item. The navigator needs to be contained in a `NavigationView`.
  ///
  /// - Parameters:
  ///   - name: The name of the folder item.
  ///   - folder: The folder item whose hierachy is being navigated.
  ///   - parent: The folder in which the item is contained, if any.
  ///   - viewModel: The file navigator view model for this folder.
  ///   - target: Payload view builder rendering for individual file payloads.
  ///   - fileLabel: A view builder to produce a label for a file.
  ///   - folderLabel: A view builder to produce a label for a folder.
  ///
  public init<S: StringProtocol>(name: S,
                                 folder: Binding<Folder<Payload>>,
                                 parent: Binding<Folder<Payload>?>,
                                 viewModel: FileNavigatorViewModel,
                                 @ViewBuilder target: @escaping TargetViewBuilder<Payload, PayloadView>,
                                 @ViewBuilder fileLabel: @escaping NavigatorViewBuilder<Payload, FileLabelView>,
                                 @ViewBuilder folderLabel: @escaping NavigatorViewBuilder<Payload, FolderLabelView>,
                                 @ViewBuilder fileMenu: @escaping NavigatorViewBuilder<Payload, FileMenuView>,
                                 @ViewBuilder folderMenu: @escaping NavigatorViewBuilder<Payload, FolderMenuView>)
  {
    self._folder     = folder
    self._parent     = parent
    self.viewModel   = viewModel
    self.name        = String(name)
    self.fileLabel   = fileLabel
    self.folderLabel = folderLabel
    self.fileMenu    = fileMenu
    self.folderMenu  = folderMenu
    self.target      = target
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
                      target: target,
                      fileLabel: fileLabel,
                      folderLabel: folderLabel,
                      fileMenu: fileMenu,
                      folderMenu: folderMenu)

      }

    } label: {

      let cursor            = FileNavigatorCursor(name: name, parent: $parent),
          editedTextBinding = viewModel.editedText(for: folder.id)

      folderLabel(cursor, editedTextBinding)
        .contextMenu{ folderMenu(cursor, editedTextBinding) }

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
    @State var viewModel = FileNavigatorViewModel(expansions: WrappedUUIDSet(), selection: nil, editedLabel: nil)

    var body: some View {

      let item = FileOrFolder<Payload>(folder: try! Folder(tree: try! treeToPayload(tree: _tree)))

      FileNavigator(name: "Root",
                    item: .constant(item),
                    parent: .constant(nil),
                    viewModel: viewModel,
                    target: { $file in Text(file.contents.text) },
                    fileLabel: { cursor, _editing in Text(cursor.name) },
                    folderLabel: { cursor, _editing in Text(cursor.name) },
                    fileMenu: { _, _ in },
                    folderMenu: { _, _ in })
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

struct FileNavigatorEditLabel_Previews: PreviewProvider {

  struct Container: View {
    @State var viewModel = FileNavigatorViewModel(expansions: WrappedUUIDSet(), selection: nil, editedLabel: nil)
    @State var item      = FileOrFolder<Payload>(folder: try! Folder(tree: try! treeToPayload(tree: _tree)))

    var body: some View {

      FileNavigator(name: "Root",
                    item: $item,
                    parent: .constant(nil),
                    viewModel: viewModel,
                    target: { $file in Text(file.contents.text) },
                    fileLabel: { cursor, $editedText in
                                   EditableLabel(cursor.name,
                                                 systemImage: "doc.plaintext.fill",
                                                 editedText: $editedText)
                                     .onSubmit {
                                       if let newName = editedText {
                                         _ = cursor.parent.wrappedValue?.rename(name: cursor.name, to: newName)
                                         editedText = nil
                                       }
                                     }
                                },
                    folderLabel: { cursor, $editedText in
                                     EditableLabel(cursor.name, systemImage: "folder.fill", editedText: $editedText)
                                       .onSubmit {
                                         if let newName = editedText {
                                           _ = cursor.parent.wrappedValue?.rename(name: cursor.name, to: newName)
                                           editedText = nil
                                         }
                                       }
                    },
                    fileMenu: { cursor, $editedText in
                      Button {
                        editedText = cursor.name
                      } label: {
                        Label("Change name", systemImage: "pencil")
                      }
                    },
                    folderMenu: { cursor, $editedText in
                      Button { 
                        editedText = cursor.name
                      } label: {
                        Label("Change name", systemImage: "pencil")
                      }
                    })
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
