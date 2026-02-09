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
    var cardColorHex: String?

    /// The two card background colors: white and warm beige
    static let cardColors = ["FFFFFF", "E8E0D4"]

    /// Pick a random card color from the palette
    static func randomCardColor() -> String {
        cardColors.randomElement() ?? "FFFFFF"
    }
}
