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


struct ContentView: View {
  let name: String

  @ObservedObject var document: NavigatorDemoDocument

  @SceneStorage("navigatorExpansions") private var expansions: WrappedUUIDSet = WrappedUUIDSet()
  @SceneStorage("navigatorSelection")  private var selection:  FileOrFolder.ID?

  var body: some View {

    NavigationView {

      List {
        FileNavigatorFolder(name: name, folder: $document.texts, expansions: $expansions, selection: $selection)
        { $file in

          if let text = file.contents.text {

            let textBinding = Binding { return text } set: { newValue in file.contents.text = newValue }
            TextEditor(text: textBinding)
              .font(.custom("HelveticaNeue", size: 15))

          } else {

            Text("Not a UTF-8 text file")

          }

        } label: { name, item in

          switch item {
          case .file:   Label(name, systemImage: "doc.plaintext.fill")
          case .folder: Label(name, systemImage: "folder.fill")
          }

        }
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
