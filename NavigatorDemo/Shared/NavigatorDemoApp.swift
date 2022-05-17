//
//  NavigatorDemoApp.swift
//  Shared
//
//  Created by Manuel M T Chakravarty on 16/05/2022.
//

import SwiftUI

@main
struct NavigatorDemoApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: NavigatorDemoDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
