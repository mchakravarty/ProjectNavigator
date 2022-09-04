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

  @Published var name:     String
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

  @StateObject var navigatorDemoModel = NavigatorDemoModel(name: "",
                                                           document: NavigatorDemoDocument())

  var body: some Scene {

    DocumentGroup(newDocument: { NavigatorDemoDocument(text: "Beautiful text!") }) { file in

      ContentView()
        .environmentObject(navigatorDemoModel)
        .onAppear {
          navigatorDemoModel.name     = file.fileURL?.lastPathComponent ?? "Untitled"
          navigatorDemoModel.document = file.document
        }
    }
  }
}
