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

  let viewState: FileNavigatorViewState<Payload>
  let model:     NavigatorDemoModel

  /// The undo manager from the SwiftUI environment.
  ///
  let undoManager: UndoManager?

  init(viewState: FileNavigatorViewState<Payload>, model: NavigatorDemoModel, undoManager: UndoManager?) {
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
    guard let newName = editedText else { return }

    registerUndo {

      _ = cursor.parent.wrappedValue?.rename(name: cursor.name, to: newName)
      editedText = nil

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

    registerUndo {
      folder.add(item: item, withPreferredName: preferredName)
    }
  }

  /// Remove the item idenfified by the given cursor.
  ///
  /// - Parameter cursor: The cursor identifying the item to be removed.
  ///
  func remove(cursor: FileNavigatorCursor<Payload>) {

    registerUndo {
      _ = cursor.parent.wrappedValue?.remove(name: cursor.name)
    }
  }

  /// Wrap a modification of the model state into a registration with the undo manager. On undo, we simply reset the
  /// state and redraw the UI.
  ///
  /// During undo, register a redo in a symmetric manner.
  ///
  private func registerUndo(action: () -> Void) {

    // Preserve old value for undo
    let oldTextsCopy = FileTree<Payload>(fileTree: model.document.texts)

    // Perform action
    action()

    // Register undoing the change
    undoManager?.registerUndo(withTarget: model) { ourModel in
      registerUndo {
        ourModel.document.texts.set(to: oldTextsCopy)
      }
    }
  }
}
