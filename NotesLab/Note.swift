//
//  Note.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import Foundation

struct Note: Identifiable, Codable {
    let id: UUID
    var title: String
    // CHANGED: Instead of one big string, we have a list of blocks
    var blocks: [NoteBlock]
    var date: Date

    init(title: String, blocks: [NoteBlock] = []) {
        self.id = UUID()
        self.title = title
        // Default to one empty text block so the note isn't blank
        self.blocks = blocks.isEmpty ? [NoteBlock.empty(type: .text)] : blocks
        self.date = Date()
    }
}
