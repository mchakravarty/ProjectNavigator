//
//  EditableLabel.swift
//  
//
//  Created by Manuel M T Chakravarty on 29/05/2022.
//

import SwiftUI


public struct EditableLabel: View {
  @Binding var text:      String
  @Binding var isEditing: Bool

  @FocusState var isFocused: Bool

  let image: Image

  /// A label whose text can be edited.
  ///
  /// - Parameters:
  ///   - text: The editable label text.
  ///   - systemImage: Name of a system image.
  ///   - isEditing: Whether the text of the label is currently being in edit mode.
  ///
  public init(_ text: Binding<String>, systemImage: String, isEditing: Binding<Bool>) {
    self._text      = text
    self.image      = Image(systemName: systemImage)
    self._isEditing = isEditing
  }

  public var body: some View {

    Label {
      if isEditing {

        TextField("", text: $text)
          .textInputAutocapitalization(.never)
          .disableAutocorrection(true)
          .focused($isFocused)
          .onAppear{
            isFocused = true
          }
          .onSubmit {
            isEditing = false
          }

      } else { Text(text) }

    } icon: { image }
  }
}


// MARK: -
// MARK: Preview

struct EditableLabel_Previews: PreviewProvider {

  struct Container: View {
    @State var text: String    = "Label"
    @State var isEditing: Bool = false

    var body: some View {

      VStack(alignment: .leading, spacing: 8) {

        Text("Click on the label to edit")
        EditableLabel($text, systemImage: "paperplane", isEditing: $isEditing)
          .onTapGesture {
            isEditing = true
          }

      }
    }
  }

  static var previews: some View {
    Container()
      .padding()
  }
}
