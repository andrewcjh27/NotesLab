
//
//  Note.swift
//  NotesLab
//

import Foundation

enum BlockType: String, Codable, CaseIterable, Hashable {
    case text
    case image
    case code
    case calculation
    case heading
}

struct NoteBlock: Identifiable, Codable, Hashable {
    var id: UUID
    var type: BlockType
    var content: String
    var hashtags: [String]
    var createdAt: Date
    var imageData: Data?
    var isBold: Bool
    var isItalic: Bool
    var useSerif: Bool
}

struct Note: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var icon: String
    var date: Date
    var blocks: [NoteBlock]
}

