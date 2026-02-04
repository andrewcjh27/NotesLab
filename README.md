Canvas (iOS)

A native iOS note-taking application built with SwiftUI and MVVM architecture. This project demonstrates core mobile development concepts including data persistence, state management, and declarative UI design.


🏗 Architecture & Design

The app follows the MVVM (Model-View-ViewModel) pattern to ensure a clean separation of concerns:

Model (Note.swift): Defines the data structure (UUID, title, content, date).

ViewModel (NotesStore.swift): Manages the application state and handles business logic.

Implements ObservableObject to reactive UI updates.

Uses JSONEncoder/JSONDecoder for local data persistence to the device's file system.

View (ContentView.swift, NoteEditorView.swift): Declarative SwiftUI views that observe the ViewModel for changes.


🚀 Features

Create & Edit: Seamlessly add new notes or edit existing ones.

Persistence: Notes are automatically saved to the local documents directory, ensuring data survives app restarts.

List Management: Swipe-to-delete functionality and dynamic list rendering.

Reactive UI: The interface updates instantly as data changes using @StateObject and @Published properties.


🛠 Tech Stack

Language: Swift 5+

Framework: SwiftUI

Platform: iOS 16.0+

IDE: Xcode


🏃‍♂️ How to Run

Clone this repository.

Open NotesLab.xcodeproj in Xcode.

Select an iOS Simulator (e.g., iPhone 15 Pro) or a physical device.

Press Cmd + R to build and run.


🔮 Future Improvements

Biometric Security: Adding FaceID to lock private notes.

Rich Text Support: Implementing Markdown rendering for biology/lab notes.

Cloud Sync: Integrating CloudKit or Firebase to sync notes across devices.

Created by Junho Choi
