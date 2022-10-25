//
//  ViewContext.swift
//  NavigatorDemo
//
//  Created by Manuel M T Chakravarty on 18/10/2022.
//
//  The view context combines view state and app model.

import SwiftUI
import Combine
import Files
import ProjectNavigator


// MARK: -
// MARK: View context

/// The view context for the demo app content view.
///
struct ViewContext {

  let viewState: FileNavigatorViewState
  let model:     NavigatorDemoModel

  /// The undo manager from the SwiftUI environment.
  ///
  let undoManager: UndoManager?

  init(viewState: FileNavigatorViewState, model: NavigatorDemoModel, undoManager: UndoManager?) {
    self.viewState       = viewState
    self.model           = model
    self.undoManager     = undoManager
  }
}


// MARK: -
// MARK: Context updates through user interaction

extension ViewContext {

  /// Rename the item identified by the cursor.
  ///
  /// - Parameters:
  ///   - cursor: The file navigator cursor identifying the item whose name is to be changed.
  ///   - to: A binding to the edited name.
  ///
  ///   The binding to the edited name is nil'ed out to indicate the completion of editing.
  ///
  func rename(cursor: FileNavigatorCursor<Payload>, @Binding to editedText: String?) {

    if let newName = editedText {

      _ = cursor.parent.wrappedValue?.rename(name: cursor.name, to: newName)
      editedText = nil

      undoManager?.registerUndo(withTarget: model) { _ in }
    }
  }

  /// Add an item to the given folder.
  ///
  /// - Parameters:
  ///   - item: The item to add.
  ///   - to: The folder to which the item is to be added.
  ///   - preferredName: The preferred name of the given item.
  ///
  ///   If the preferred name is already taken, an alternative name, derived from the preferred name, will be used.
  ///
  func add(item: FullFileOrFolder<Payload>, @Binding to folder: ProxyFolder<Payload>, withPreferredName preferredName: String) {

    folder.add(item: item, withPreferredName: preferredName)

    undoManager?.registerUndo(withTarget: model) { _ in }
  }

  /// Remove the item idenfified by the given cursor.
  ///
  /// - Parameter cursor: The cursor identifying the item to be removed.
  ///
  func remove(cursor: FileNavigatorCursor<Payload>) {

    _ = cursor.parent.wrappedValue?.remove(name: cursor.name)

    undoManager?.registerUndo(withTarget: model) { _ in }
  }
}
