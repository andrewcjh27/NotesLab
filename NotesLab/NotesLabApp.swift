//
//  NotesLabApp.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import SwiftUI

@main
struct NotesLabApp: App {
    @StateObject private var store = NotesStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
