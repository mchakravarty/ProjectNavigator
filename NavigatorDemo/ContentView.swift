//
//  ContentView.swift
//  Shared
//
//  Created by Manuel M T Chakravarty on 16/05/2022.
//

import SwiftUI
import Files
import ProjectNavigator


// MARK: -
// MARK: UUID serialisation

extension UUID: RawRepresentable {

  public var rawValue: String { uuidString }

  public init?(rawValue: String) {
    self.init(uuidString: rawValue)
  }
}


// MARK: -
// MARK: Views

struct FileContextMenu: View {
  let cursor: FileNavigatorCursor<Payload>

  @Binding var editedText: String?
  @Binding var file:       File<Payload>

  var body: some View {

    Button {
      editedText = cursor.name
    } label: {
      Label("Change name", systemImage: "pencil")
    }

    Divider()

    Button(role: .destructive) {

      withAnimation {
        _ = cursor.parent.wrappedValue?.remove(name: cursor.name)
      }

    } label: {
      Label("Delete", systemImage: "trash")
    }

  }
}

struct FolderContextMenu: View {
  let cursor: FileNavigatorCursor<Payload>

  @Binding var editedText: String?
  @Binding var folder:     Folder<Payload>

  var body: some View {

    Button {
      withAnimation {
        folder.add(item: FileOrFolder(file: File(contents: Payload(text: ""))),
                   withPreferredName: "Text.txt")

//                !!!Now we need to be able to edit the name of the newly added file.
      }
    } label: {
      Label("New file", systemImage: "doc.badge.plus")
    }

    Button {
      withAnimation {
        folder.add(item: FileOrFolder(folder: Folder(children: [:])),
                   withPreferredName: "Folder")

//                !!!Now we need to be able to edit the name of the newly added file.
      }
    } label: {
      Label("New folder", systemImage: "folder.badge.plus")
    }

    // Only support rename and delete action if this menu doesn't apply to the root folder
    if cursor.parent.wrappedValue != nil {

      Divider()
      
      Button {
        editedText = cursor.name
      } label: {
        Label("Change name", systemImage: "pencil")
      }

      Divider()

      Button(role: .destructive) {

        withAnimation {
          _ = cursor.parent.wrappedValue?.remove(name: cursor.name)
        }

      } label: {
        Label("Delete", systemImage: "trash")
      }

    }

  }
}

struct Navigator: View {
  @ObservedObject var viewModel: FileNavigatorViewModel<Payload>

  @EnvironmentObject var model: NavigatorDemoModel

  var body: some View {

    NavigationSplitView {

      List(selection: $viewModel.selection) {

        FileNavigatorFolder(name: model.name,
                            folder: $model.document.texts,
                            parent: .constant(nil),
                            viewModel: viewModel)
        { cursor, $editedText, $file in

          EditableLabel(cursor.name, systemImage: "doc.plaintext.fill", editedText: $editedText)
            .onSubmit {
              if let newName = editedText {
                _ = cursor.parent.wrappedValue?.rename(name: cursor.name, to: newName)
                editedText = nil
              }
            }
            .contextMenu{ FileContextMenu(cursor: cursor, editedText: $editedText, file: $file) }

        } folderLabel: { cursor, $editedText, $folder in

          EditableLabel(cursor.name, systemImage: "folder.fill", editedText: $editedText)
            .onSubmit {
              if let newName = editedText {
                _ = cursor.parent.wrappedValue?.rename(name: cursor.name, to: newName)
                editedText = nil
              }
            }
            .contextMenu{ FolderContextMenu(cursor: cursor, editedText: $editedText, folder: $folder) }

        }
        .navigatorFilter{ $0.first != Character(".") }
      }
      .listStyle(.sidebar)

    } detail: {

      if let $file = viewModel.selectedFile {

        if let $text = Binding($file.contents.text) {

          TextEditor(text: $text)
            .font(.custom("HelveticaNeue", size: 15))

        } else {

          Text("Not a UTF-8 text file")

        }

      } else { Text("Select a file") }

    }
  }
}


/// This is the toplevel content view. It expects the app model as the environment object.
///
struct ContentView: View {

  @SceneStorage("navigatorExpansions") private var expansions: WrappedUUIDSet?
  @SceneStorage("navigatorSelection")  private var selection:  FileOrFolder.ID?

  @StateObject private var fileNavigationViewModel = FileNavigatorViewModel<Payload>()

  var body: some View {

    Navigator(viewModel: fileNavigationViewModel)
      .task {
        if let savedExpansions = expansions {
          fileNavigationViewModel.expansions = savedExpansions
        }
        for await newExpansions in fileNavigationViewModel.$expansions.values {
          expansions = newExpansions
        }
      }
      .task {
        if let savedSelection = selection {
          fileNavigationViewModel.selection = savedSelection
        }
        for await newSelection in fileNavigationViewModel.$selection.values {
          selection = newSelection
        }
      }
  }
}


// MARK: -
// MARK: Preview

struct ContentView_Previews: PreviewProvider {

  struct Container: View {
    let document = NavigatorDemoDocument()

    var body: some View {
      ContentView()
        .environmentObject(NavigatorDemoModel(name: "Test", document: document))
    }
  }

  static var previews: some View {
    Container()
  }
}
