//
//  EditableLabel.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/05/2022.
//

import SwiftUI


/// A label whose text can be edited.
///
public struct EditableLabel: View {
  let text:  String
  let image: Image

  @Binding var editedText: String?

  @FocusState var isFocused: Bool

  /// A label whose text can be edited.
  ///
  /// - Parameters:
  ///   - text: The label text.
  ///   - systemImage: Name of a system image.
  ///   - editedText: If non-nil, this text is being edited, while the label text is not shown.
  ///
  ///  Editing is aborted and the text before editing restored on exit.
  ///
  public init(_ text: String, systemImage: String, editedText: Binding<String?>) {
    self.text      = text
    self.image     = Image(systemName: systemImage)
    self._editedText = editedText
  }

  public var body: some View {

    Label {
      if let unwrappedEditedText = Binding(unwrap: $editedText) {

        TextField("", text: unwrappedEditedText)
#if os(iOS)
          .textInputAutocapitalization(.never)
#endif
          .disableAutocorrection(true)
          .focused($isFocused)
          .onAppear{
            isFocused = true
          }
#if os(macOS)
          .onExitCommand {
            editedText = nil
          }
#endif

      } else { Text(text) }

    } icon: { image }
  }
}


// MARK: -
// MARK: Helper

extension Binding {

  // Inspired by https://pointfree.co as an alternative to the force unwrapping version of SwiftUI.
  init?(unwrap binding: Binding<Value?>) {
    guard let wrappedValue = binding.wrappedValue
    else { return nil }

    self.init(
      get: { wrappedValue },
      set: { binding.wrappedValue = $0 }
    )
  }
}


// MARK: -
// MARK: Preview

struct EditableLabel_Previews: PreviewProvider {

  struct Container: View {
    @State var text:       String  = "Label"
    @State var editedText: String? = nil

    var body: some View {

      VStack(alignment: .leading, spacing: 8) {

        Text("Click on the label to edit")
        EditableLabel(text, systemImage: "paperplane", editedText: $editedText)
          .onTapGesture {
            editedText = text
          }
          .onSubmit {
            if editedText == "" { return }
            if let editedText = editedText { text = editedText }
            editedText = nil
          }

      }
    }
  }

  static var previews: some View {
    Container()
      .padding()
  }
}
