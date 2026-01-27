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
    var content: String
    var date: Date

    init(title: String, content: String) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.date = Date()
    }
}
