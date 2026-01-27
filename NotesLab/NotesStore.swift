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
        let documentDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        saveURL = documentDirectory.appendingPathComponent("notes.json")
        loadNotes()
    }

    func addNote(title: String, content: String) {
        let newNote = Note(title: title, content: content)
        notes.insert(newNote, at: 0)
        saveNotes()
    }

    func deleteNote(at offsets: IndexSet) {
        notes.remove(atOffsets: offsets)
        saveNotes()
    }

    func updateNote(note: Note, title: String, content: String) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].title = title
            notes[index].content = content
            notes[index].date = Date()
            saveNotes()
        }
    }

    private func saveNotes() {
        do {
            let data = try JSONEncoder().encode(notes)
            try data.write(to: saveURL)
        } catch {
            print("Failed to save notes:", error)
        }
    }

    private func loadNotes() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else { return }

        do {
            let data = try Data(contentsOf: saveURL)
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            print("Failed to load notes:", error)
        }
    }
}
