//
//  ContentView.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = NotesStore()
    @State private var showNewNote = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.notes) { note in
                    NavigationLink {
                        NoteEditorView(note: note, store: store)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(note.title)
                                .font(.headline)

                            // CHANGED: Safely getting preview text from the first block
                            Text(note.blocks.first?.content ?? "No content")
                                .lineLimit(2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: store.deleteNote)
            }
            .navigationTitle("Notes")
            .toolbar {
                Button {
                    showNewNote = true
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showNewNote) {
                NewNoteView(store: store)
            }
        }
    }
}
