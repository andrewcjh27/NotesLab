//
//  Note.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import Foundation

// 1. Block Types
enum BlockType: String, Codable, CaseIterable {
    case text = "Text"
    case heading = "Heading"
    case code = "Code"
    case calculation = "Math"
    case image = "Image"
}

// Define the available fonts
enum BlockFont: String, Codable, CaseIterable {
    case standard = "Standard"
    case serif = "Serif"
    case mono = "Mono"
    case rounded = "Rounded"
}

// 2. The Block Structure
struct NoteBlock: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: BlockType
    var content: String
    var imageData: Data?
    
    // Formatting properties
    var fontStyle: BlockFont = .standard
    var isBold: Bool = false
    var isItalic: Bool = false
    
    static func empty(type: BlockType) -> NoteBlock {
        return NoteBlock(type: type, content: "", fontStyle: .standard, isBold: false, isItalic: false)
    }
}

// 3. The Main Note Structure
struct Note: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var icon: String // The emoji icon for the note
    var blocks: [NoteBlock]
    var date: Date

    // CHANGED: Default icon is now 📄 to match your request
    init(title: String, icon: String = "📄", blocks: [NoteBlock] = []) {
        self.id = UUID()
        self.title = title
        self.icon = icon
        self.blocks = blocks.isEmpty ? [NoteBlock.empty(type: .text)] : blocks
        self.date = Date()
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        
        // CHANGED: Default to 📄 if missing
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "📄"
        
        blocks = try container.decode([NoteBlock].self, forKey: .blocks)
        date = try container.decode(Date.self, forKey: .date)
    }
}
