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
  let image: any View

  @Binding var editedText: String?

  @FocusState private var isFocused: Bool

  /// A label whose text can be edited.
  ///
  /// - Parameters:
  ///   - text: The label text.
  ///   - image: Image to use for the label. It will be scaled to fit.
  ///   - editedText: If non-nil, this text is being edited, while the label text is not shown.
  ///
  ///  Editing is aborted and the text before editing restored on exit.
  ///
  public init(_ text: String, image: Image, editedText: Binding<String?>) {
    self.text        = text
    self.image       = image.resizable().scaledToFit()
    self._editedText = editedText
  }

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
    self.text        = text
    self.image       = Image(systemName: systemImage)
    self._editedText = editedText
  }

  public var body: some View {

    Label {

      if let $unwrappedEditedText = Binding(unwrap: $editedText) {

        TextField(text: $unwrappedEditedText, label: { EmptyView() })
          .textFieldStyle(.plain)
          .focused($isFocused)
          .onAppear {
            // FIXME: For some reason, we need to delay this assignment; otherwise, the label does not get the
            // FIXME: focus. This is weird, because a simple test app using basically the same set up, does not
            // FIXME: need the same sort of delay.
            Task { @MainActor in
              isFocused = true
            }
          }
          .disableAutocorrection(true)
#if os(iOS)
          .textInputAutocapitalization(.never)
#endif
#if os(macOS)
          .onExitCommand {
            editedText = nil
          }
#endif
          .onChange(of: isFocused) {
            if !isFocused { editedText = nil }
          }

      } else { Text(text) }

    } icon: {
      AnyView(image)
    }
  }
}


// MARK: -
// MARK: Helper

// TODO: This definition should go into a more general module.
extension Binding {

  /// Produce a binding to the non-nil subset of a binding of an optional value. It uses the initial value as a default
  /// when queried (`get`) while the original binding returns nil.
  ///
  /// - Parameter binding: The original binding to an optional value.
  ///
  /// Inspired by https://pointfree.co as an alternative to the force unwrapping version of SwiftUI.
  ///
  @MainActor
  public init?(unwrap binding: Binding<Value?>) {
    guard let value = binding.wrappedValue
    else { return nil }

    self.init(
             // TODO: The last delivered value would be better, but that isn't available...
      get: { binding.wrappedValue ?? value },
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
            if let editedText { text = editedText }
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
