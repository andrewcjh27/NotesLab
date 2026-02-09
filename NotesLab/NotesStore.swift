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
    @Published var saveError: String?

    private let saveURL: URL
    private var saveTask: Task<Void, Never>?

    init() {
        guard let documentDirectory = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first else {
            fatalError("Unable to access document directory")
        }
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
            blocks: [initialBlock],
            cardColorHex: Note.randomCardColor()
        )

        notes.insert(newNote, at: 0)
        debouncedSave()
        return newNote
    }

    func addNote(title: String) {
        let newNote = Note(
            id: UUID(),
            title: title,
            icon: "📄",
            date: Date(),
            blocks: [],
            cardColorHex: Note.randomCardColor()
        )

        notes.insert(newNote, at: 0)
        debouncedSave()
    }

    // Used by List swipe actions
    func deleteNote(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        debouncedSave()
    }

    // Helper to delete a specific note object (useful for Grid context menu)
    func deleteNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes.remove(at: index)
            debouncedSave()
        }
    }

    func updateNote(_ updatedNote: Note) {
        if let index = notes.firstIndex(where: { $0.id == updatedNote.id }) {
            notes[index] = updatedNote
            notes[index].date = Date()
            debouncedSave()
        }
    }

    /// Swap two notes by their IDs (used for drag-and-drop reordering on the grid)
    func swapNotes(fromID: UUID, toID: UUID) {
        guard let fromIndex = notes.firstIndex(where: { $0.id == fromID }),
              let toIndex = notes.firstIndex(where: { $0.id == toID }),
              fromIndex != toIndex else { return }

        notes.swapAt(fromIndex, toIndex)
        debouncedSave()
    }

    private func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second debounce
            guard !Task.isCancelled else { return }
            saveNotes()
        }
    }

    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: saveURL, options: .atomic)
            saveError = nil
        } catch {
            print("Failed to save:", error)
            saveError = "Failed to save notes: \(error.localizedDescription)"
        }
    }

    private func loadNotes() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }
        do {
            let data = try Data(contentsOf: saveURL)
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            print("Failed to load:", error)
            saveError = "Failed to load notes: \(error.localizedDescription)"
        }
    }
}

