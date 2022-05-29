//
//  ContentView.swift
//  Shared
//
//  Created by Manuel M T Chakravarty on 16/05/2022.
//

import SwiftUI
import Files
import ProjectNavigator


extension UUID: RawRepresentable {

  public var rawValue: String { uuidString }

  public init?(rawValue: String) {
    self.init(uuidString: rawValue)
  }
}

struct FileContextMenu: View {
  let name: String

  @Binding var file:   File<Payload>
  @Binding var parent: Folder<Payload>?

  var body: some View {

    Button {

    } label: {
      Label("Change name", systemImage: "pencil")
    }

    Divider()

    Button(role: .destructive) {

      withAnimation {
        _ = parent?.remove(name: name)
      }

    } label: {
      Label("Delete", systemImage: "trash")
    }

  }
}

struct FolderContextMenu: View {
  let name: String

  @Binding var folder: Folder<Payload>
  @Binding var parent: Folder<Payload>?

  @EnvironmentObject var document: NavigatorDemoDocument

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

    Divider()

    Button {

    } label: {
      Label("Change name", systemImage: "pencil")
    }

    // Only support a delete action if this menu doesn't apply to the root folder
    if parent != nil {

      Divider()

      Button(role: .destructive) {

        withAnimation {
          _ = parent?.remove(name: name)
        }

      } label: {
        Label("Delete", systemImage: "trash")
      }

    }

  }
}

struct ContentView: View {
  let name: String

  @ObservedObject var document: NavigatorDemoDocument

  @SceneStorage("navigatorExpansions") private var expansions: WrappedUUIDSet = WrappedUUIDSet()
  @SceneStorage("navigatorSelection")  private var selection:  FileOrFolder.ID?

  var body: some View {

    NavigationView {

      List {
        FileNavigatorFolder(name: name,
                            folder: $document.texts,
                            parent: .constant(nil),
                            expansions: $expansions,
                            selection: $selection)
        { $file in

          if let text = file.contents.text {

            let textBinding = Binding { return text } set: { newValue in file.contents.text = newValue }
            TextEditor(text: textBinding)
              .font(.custom("HelveticaNeue", size: 15))

          } else {

            Text("Not a UTF-8 text file")

          }

        } fileLabel: { name, _file in

          Label(name, systemImage: "doc.plaintext.fill")

        } folderLabel: { name, _folder in

          Label(name, systemImage: "folder.fill")

        } fileMenu: { name, $file, $parent in

          FileContextMenu(name: name, file: $file, parent: $parent)

        } folderMenu: { name, $folder, $parent in

          FolderContextMenu(name: name, folder: $folder, parent: $parent)

        }
        .navigatorFilter{ $0.first != Character(".") }
      }
      .listStyle(.sidebar)

      Text("Select a file")
    }
    .navigationViewStyle(.columns)
  }
}


struct ContentView_Previews: PreviewProvider {

  struct Container: View {
    @State var document = NavigatorDemoDocument()

    var body: some View {
      ContentView(name: "Test", document: document)
    }
  }

  static var previews: some View {
    Container()
  }
}
