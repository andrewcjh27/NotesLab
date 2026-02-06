//
//  NewNoteView.swift
//  NotesLab
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

    var body: some View {
        VStack(spacing: 20) {
            Text("Create New Note")
                .font(.headline)
                .padding(.top)

            TextField("Enter Note Title", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            Spacer()

            Button("Create Note") {
                store.addNote(title: title)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.isEmpty)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 200)
    }
}
