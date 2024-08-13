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

  let proxy:       File<Payload>.Proxy
  let viewContext: ViewContext

  var body: some View {

    Button {
      editedText = cursor.name
    } label: {
      Label("Change name", systemImage: "pencil")
    }

    Divider()

    Button(role: .destructive) {

      withAnimation {
        viewContext.remove(id: proxy.id, cursor: cursor)
      }

    } label: {
      Label("Delete", systemImage: "trash")
    }

  }
}

struct FolderContextMenu: View {
  let cursor: FileNavigatorCursor<Payload>

  @Binding var editedText: String?
  @Binding var folder:     ProxyFolder<Payload>

  let viewContext: ViewContext

  var body: some View {

    Button {
      withAnimation {
        viewContext.add(item: FileOrFolder(file: File(contents: Payload(text: ""))),
                        $to: $folder,
                        withPreferredName: "Text.txt")
      }
    } label: {
      Label("New file", systemImage: "doc.badge.plus")
    }

    Button {
      withAnimation {
        viewContext.add(item: FileOrFolder(folder: Folder(children: [:])), $to: $folder, withPreferredName: "Folder")
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
          viewContext.remove(id: folder.id, cursor: cursor)
        }

      } label: {
        Label("Delete", systemImage: "trash")
      }

    }

  }
}

struct Navigator: View {
  @Bindable var viewState: FileNavigatorViewState<Payload>

  @Environment(NavigatorDemoModel.self) private var model: NavigatorDemoModel

  @Environment(\.undoManager) var undoManager: UndoManager?

  // Used by the undo manager logic to be able to distinguish between changes made to the text by the user and changes
  // made by the undo manager.
  @State private var changeByUndoManager: Bool = false

  var body: some View {

    @Bindable var model = model
    let viewContext = ViewContext(viewState: viewState, model: model, undoManager: undoManager)
    NavigationSplitView {

      VStack {

        List(selection: $viewState.selection) {

          FileNavigator(name: model.name,
                        item: $model.document.texts.root,
                        parent: .constant(nil),
                        viewState: viewState)
          { cursor, $editedText, proxy in

            EditableLabel(cursor.name, systemImage: "doc.plaintext.fill", editedText: $editedText)
              .onSubmit{ viewContext.rename(cursor: cursor, $to: $editedText) }
              .contextMenu{ FileContextMenu(cursor: cursor,
                                            editedText: $editedText,
                                            proxy: proxy,
                                            viewContext: viewContext) }

          } folderLabel: { cursor, $editedText, $folder in

            EditableLabel(cursor.name, systemImage: "folder.fill", editedText: $editedText)
              .onSubmit{ viewContext.rename(cursor: cursor, $to: $editedText) }
              .contextMenu{ FolderContextMenu(cursor: cursor,
                                              editedText: $editedText,
                                              folder: $folder,
                                              viewContext: viewContext) }

          }
          .navigatorFilter{ $0.first != Character(".") }
        }
        .listStyle(.sidebar)
        .navigationTitle(model.name)
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif


        if let dominantFolder = viewState.dominantFolder?.wrappedValue  {

          let name = model.document.texts.filePath(of: dominantFolder.id).lastComponent?.string ?? model.name
          VStack(alignment: .leading) {
            Divider()
            Text(name)
              .padding([.leading, .bottom], 4)
          }

        }
      }

    } detail: {

      if let uuid = viewState.selection,
         // NB: We need our own unwrapping version here (not the implicitly unwrapping one from Apple); otherwise,
         //     we crash when removing the currently selected file. It would be better to avoid the crash in a
         //     different manner.
         let $file = Binding(unwrap: model.document.texts.proxy(for: uuid).binding) {

        if let $text = Binding($file.contents.text) {

          VStack(alignment: .leading) {

            Text(model.name + "/" + model.document.texts.filePath(of: uuid).string)
              .padding(EdgeInsets(top: 8, leading: 8, bottom: 0, trailing: 8))
            TextEditor(text: $text)
              .font(.custom("HelveticaNeue", size: 15))
              .onChange(of: $text.wrappedValue) { (oldValue, newValue) in
                guard !changeByUndoManager else {
                  changeByUndoManager = false
                  return
                }

#if os(iOS) || os(visionOS)
                // On iOS, the `TextEditor` uses its own local undo manager instead of the one provided by the SwiftUI
                // environment. Hence, the SwiftUI document system is not informed of changes to the text by the
                // `TextEditor`. As a consequence, (auto)saving does not work.
                //
                // The following codes works around this issues by explicitly registering text changes with the undo
                // manager provided by the SwiftUI document system. This is only a work around and not a proper solution
                // as it will also undo changes made to the text outside of the `TextEditor`. (This is not a problem
                // in this little demo app.)
                undoManager?.registerUndo(withTarget: model) { [weak undoManager] _ in
                  $text.wrappedValue = oldValue
                  changeByUndoManager =  true
                  undoManager?.registerUndo(withTarget: model) { _ in
                    $text.wrappedValue = newValue
                    changeByUndoManager =  true
                  }
                }
#endif
              }

          }

        } else { Text("Not a UTF-8 text file") }

      } else { Text("Select a file") }

    }
  }
}


/// This is the toplevel content view. It expects the app model as the environment object.
///
struct ContentView: View {
  let configuration: ReferenceFileDocumentConfiguration<NavigatorDemoDocument>?

  @SceneStorage("navigatorExpansions") private var expansions: WrappedUUIDSet?
  @SceneStorage("navigatorSelection")  private var selection:  FileOrFolder.ID?

  @State private var navigatorDemoModel      = NavigatorDemoModel(name: "Test", document: NavigatorDemoDocument())
  @State private var fileNavigationViewState = FileNavigatorViewState<Payload>()

  var body: some View {

    Navigator(viewState: fileNavigationViewState)
      .onAppear {
        if let savedExpansions = expansions {
          fileNavigationViewState.expansions = savedExpansions
        }
      }
      .onChange(of: fileNavigationViewState.expansions) {
          expansions = fileNavigationViewState.expansions
      }
      .onAppear {
        if let savedSelection = selection {
          fileNavigationViewState.selection = savedSelection
        }
      }
      .onChange(of: fileNavigationViewState.selection) {
          selection = fileNavigationViewState.selection
      }
#if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
#endif
      .environment(navigatorDemoModel)
      .onAppear {
        if let configuration,
           navigatorDemoModel.fileURL == nil
        {
          navigatorDemoModel.name     = configuration.fileURL?.lastPathComponent ?? "Untitled"
          navigatorDemoModel.fileURL  = configuration.fileURL
          navigatorDemoModel.document = configuration.document
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
      ContentView(configuration: nil)
    }
  }

  static var previews: some View {
    Container()
  }
}
