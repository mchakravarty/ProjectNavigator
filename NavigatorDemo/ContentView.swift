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
// MARK: View model

final class NavigatorDemoViewModel: ObservableObject {

  let name: String    // We don't support document name changes in this demo.

  @Published var document: NavigatorDemoDocument

  init(name: String, document: NavigatorDemoDocument) {
    self.name       = name
    self.document   = document
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

  @EnvironmentObject var viewModel: FileNavigatorViewModel<NavigatorDemoViewModel, Payload>

  var body: some View {

    NavigationSplitView {

      List(selection: $viewModel.selection) {

        FileNavigatorFolder(name: viewModel.model.name,
                            folder: $viewModel.model.document.texts,
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


struct ContentView: View {
  let name:     String
  let document: NavigatorDemoDocument

  @SceneStorage("navigatorExpansions") private var expansions: WrappedUUIDSet = WrappedUUIDSet()
  @SceneStorage("navigatorSelection")  private var selection:  FileOrFolder.ID?

  var body: some View {

    let navigatorDemoViewModel = NavigatorDemoViewModel(name: name, document: document)
    Navigator()
      .environmentObject(FileNavigatorViewModel<NavigatorDemoViewModel, Payload>(model: navigatorDemoViewModel,
                                                                                 expansions: WrappedUUIDSet(),
                                                                                 selection: nil,
                                                                                 editedLabel: nil))
  }
}


// MARK: -
// MARK: Preview

struct ContentView_Previews: PreviewProvider {

  struct Container: View {
    let document = NavigatorDemoDocument()

    var body: some View {
      ContentView(name: "Test", document: document)
    }
  }

  static var previews: some View {
    Container()
  }
}
