//
//  NavigatorDemoApp.swift
//  Shared
//
//  Created by Manuel M T Chakravarty on 16/05/2022.
//

import Observation
import SwiftUI


// MARK: -
// MARK: App model

@Observable
final class NavigatorDemoModel {

  var name:     String
  var document: NavigatorDemoDocument

  init(name: String, document: NavigatorDemoDocument) {
    self.name       = name
    self.document   = document
  }
}


// MARK: -
// MARK: The app

@main
struct NavigatorDemoApp: App {

  @State var navigatorDemoModel = NavigatorDemoModel(name: "", document: NavigatorDemoDocument())

  var body: some Scene {

    DocumentGroup(newDocument: { NavigatorDemoDocument(text: "Beautiful text!") }) { file in

      ContentView()
        .environment(navigatorDemoModel)
        .onAppear {
          navigatorDemoModel.name     = file.fileURL?.lastPathComponent ?? "Untitled"
          navigatorDemoModel.document = file.document
        }
    }
  }
}
