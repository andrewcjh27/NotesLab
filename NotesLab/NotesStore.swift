//
//  NotesStore.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import Foundation
import SwiftUI
import Combine

class NotesStore: ObservableObject {
    @Published var notes: [Note] = []

    private let saveURL: URL

    init() {
        let documentDirectory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
        saveURL = documentDirectory.appendingPathComponent("notes_v2.json")
        loadNotes()
    }

    // Create a note starting with a specific block type (Text, Image, etc.)
    func createNote(with type: BlockType) -> Note {
        let initialBlock = NoteBlock(
            id: UUID(),
            type: type,
            content: "",
            hashtags: [],
            createdAt: Date(),
            imageData: nil,
            isBold: false,
            isItalic: false,
            useSerif: false
        )

        let newNote = Note(
            id: UUID(),
            title: "",
            icon: "📄",
            date: Date(),
            blocks: [initialBlock]
        )

        notes.insert(newNote, at: 0)
        saveNotes()
        return newNote
    }

    func addNote(title: String) {
        let newNote = Note(
            id: UUID(),
            title: title,
            icon: "📄",
            date: Date(),
            blocks: []
        )

        notes.insert(newNote, at: 0)
        saveNotes()
    }

    // Used by List swipe actions
    func deleteNote(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        saveNotes()
    }

    // Helper to delete a specific note object (useful for Grid context menu)
    func deleteNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes.remove(at: index)
            saveNotes()
        }
    }

    func updateNote(_ updatedNote: Note) {
        if let index = notes.firstIndex(where: { $0.id == updatedNote.id }) {
            notes[index] = updatedNote
            notes[index].date = Date()
            saveNotes()
        }
    }

    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: saveURL)
        } catch {
            print("Failed to save:", error)
        }
    }

    private func loadNotes() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            print("Failed to load:", error)
        }
    }
}

