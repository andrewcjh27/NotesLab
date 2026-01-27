//
//  Note.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import Foundation

struct NoteBlock: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: BlockType
    var content: String
    var imageData: Data?
    
    static func empty(type: BlockType) -> NoteBlock {
        return NoteBlock(type: type, content: "")
    }
}

enum BlockType: String, Codable, CaseIterable {
    case text = "Text"
    case heading = "Heading"
    case code = "Code"
    case calculation = "Math"
    case image = "Image"
}

struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var blocks: [NoteBlock]
    var date: Date

    init(title: String, blocks: [NoteBlock] = []) {
        self.id = UUID()
        self.title = title
        self.blocks = blocks.isEmpty ? [NoteBlock.empty(type: .text)] : blocks
        self.date = Date()
    }
}
