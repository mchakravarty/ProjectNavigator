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
  var fileURL:  URL?
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

  var body: some Scene {

    DocumentGroup(newDocument: { NavigatorDemoDocument(text: "Beautiful text!") },
                  editor: { ContentView(configuration: $0) })
  }
}
