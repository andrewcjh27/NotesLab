//
//  ContentView.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import SwiftUI
import UIKit // Needed for stripping HTML tags

struct ContentView: View {
    @StateObject private var store = NotesStore()
    @State private var showNewNote = false
    
    // State for renaming
    @State private var noteToRename: Note?
    @State private var newTitle: String = ""
    @State private var showRenameAlert = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.notes) { note in
                    NavigationLink {
                        NoteEditorView(note: note, store: store)
                    } label: {
                        HStack(spacing: 12) {
                            // Display the emoji icon
                            Text(note.icon)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                            
                            VStack(alignment: .leading) {
                                Text(note.title)
                                    .font(.headline)

                                // CHANGED: Use the helper to strip HTML tags for the preview
                                Text(getPreviewText(for: note.blocks.first))
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    // SWIPE ACTIONS: Delete and Rename
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            if let index = store.notes.firstIndex(where: { $0.id == note.id }) {
                                store.deleteNote(at: IndexSet(integer: index))
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            noteToRename = note
                            newTitle = note.title
                            showRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
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
            // Alert to handle renaming
            .alert("Rename Note", isPresented: $showRenameAlert) {
                TextField("New Title", text: $newTitle)
                Button("Cancel", role: .cancel) { }
                Button("Rename") {
                    if let note = noteToRename {
                        var updatedNote = note
                        updatedNote.title = newTitle
                        store.updateNote(updatedNote)
                    }
                }
            }
        }
    }
    
    // --- HELPERS ---
    
    // Decides how to preview the block based on its type
    func getPreviewText(for block: NoteBlock?) -> String {
        guard let block = block else { return "No content" }
        
        // If it's a Text block, it contains HTML that needs stripping
        if block.type == .text {
            return stripHTML(from: block.content)
        } else {
            // Other blocks (Code, Heading, Math) are already plain text
            return block.content.isEmpty ? "No content" : block.content
        }
    }
    
    // Converts HTML string (like <!DOCTYPE...) into readable plain text
    func stripHTML(from text: String) -> String {
        // Optimization: If no tags, just return the text
        guard text.contains("<") else { return text }
        
        var plain = text
        
        // 1. REMOVE STYLE/HEAD BLOCKS: This fixes the "p.p1 {margin..." issue.
        // (?s) enables dot matching newlines to catch multi-line blocks
        plain = plain.replacingOccurrences(of: "(?s)<style.*?>.*?</style>", with: "", options: .regularExpression)
        plain = plain.replacingOccurrences(of: "(?s)<head.*?>.*?</head>", with: "", options: .regularExpression)
        
        // 2. Remove all remaining tags (like <p>, <b>, etc.)
        plain = plain.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 3. Fix common HTML entities
        plain = plain.replacingOccurrences(of: "&nbsp;", with: " ")
        plain = plain.replacingOccurrences(of: "&lt;", with: "<")
        plain = plain.replacingOccurrences(of: "&gt;", with: ">")
        plain = plain.replacingOccurrences(of: "&amp;", with: "&")
        
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No additional text" : trimmed
    }
}
