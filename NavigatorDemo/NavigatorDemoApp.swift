//
//  NavigatorDemoApp.swift
//  Shared
//
//  Created by Manuel M T Chakravarty on 16/05/2022.
//

import SwiftUI


// MARK: -
// MARK: App model

final class NavigatorDemoModel: ObservableObject {

  let name: String    // We don't support document name changes in this demo.

  @Published var document: NavigatorDemoDocument

  init(name: String, document: NavigatorDemoDocument) {
    self.name       = name
    self.document   = document
  }
}


// MARK: -
// MARK: The app

@main
struct NavigatorDemoApp: App {

  var body: some Scene {

    DocumentGroup(newDocument: { NavigatorDemoDocument() }) { file in

      let name = file.fileURL?.lastPathComponent ?? "Untitled"
      ContentView()
        .environmentObject(NavigatorDemoModel(name: name, document: file.document))
    }
  }
}
