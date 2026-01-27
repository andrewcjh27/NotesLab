//
//  DataModels.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/27/26.
//

import Foundation
import SwiftUI

// 1. Block Types
// This enum defines what KIND of data a block holds.
// 'Codable' allows us to save this classification to disk.
enum BlockType: String, Codable, CaseIterable {
    case text = "Text"
    case heading = "Heading"
    case code = "Code"
    case calculation = "Math"
    case image = "Image"
}

// 2. The Block Structure
// This is the atomic unit of your notebook.
struct NoteBlock: Identifiable, Codable {
    var id: UUID = UUID()
    var type: BlockType
    var content: String     // Stores text, code, or math formulas
    var imageData: Data?    // Stores the raw image data (if type == .image)
    
    // A helper to create an empty block easily
    static func empty(type: BlockType) -> NoteBlock {
        return NoteBlock(type: type, content: "")
    }
}
