//
//  NewNoteView.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import SwiftUI

struct NewNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: NotesStore

    @State private var title = ""
    @State private var content = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField("Title", text: $title)
                .font(.title2)

            TextEditor(text: $content)
                .frame(minHeight: 200)

            Spacer()

            Button("Save") {
                store.addNote(title: title, content: content)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.isEmpty)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
