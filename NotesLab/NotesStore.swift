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
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        saveURL = documentDirectory.appendingPathComponent("notes_v2.json") // Changed name to avoid conflicts
        loadNotes()
    }

    func addNote(title: String) {
        // Create a note with one default text block
        let newNote = Note(title: title)
        notes.insert(newNote, at: 0)
        saveNotes()
    }

    func deleteNote(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        saveNotes()
    }

    // CHANGED: We now accept the entire updated Note object
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
