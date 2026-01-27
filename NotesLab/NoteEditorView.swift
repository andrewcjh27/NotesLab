//
//  NoteEditorView.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import SwiftUI

struct NoteEditorView: View {
    let note: Note
    @ObservedObject var store: NotesStore

    @State private var title: String
    @State private var content: String

    init(note: Note, store: NotesStore) {
        self.note = note
        self.store = store
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content)
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("Title", text: $title)
                .font(.title)

            TextEditor(text: $content)

            Spacer()
        }
        .padding()
        .onDisappear {
            store.updateNote(note: note, title: title, content: content)
        }
    }
}

