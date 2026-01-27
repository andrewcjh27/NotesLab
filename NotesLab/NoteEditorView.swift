//
//  NoteEditorView.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import SwiftUI
import PhotosUI // Required for picking images

struct NoteEditorView: View {
    // We use @State so we can edit the note locally before saving
    @State private var note: Note
    @ObservedObject var store: NotesStore
    
    // For Image Picking
    @State private var selectedItem: PhotosPickerItem? = nil
    
    // We need to initialize the state with the passed-in note
    init(note: Note, store: NotesStore) {
        self._note = State(initialValue: note)
        self.store = store
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 1. Main Title
                TextField("Note Title", text: $note.title)
                    .font(.largeTitle.bold())
                    .padding(.bottom)
                
                // 2. The Loop: Rendering every block
                // $note.blocks.indices allows us to bind to the array directly
                ForEach($note.blocks.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        // The actual content block
                        renderBlock(binding: $note.blocks[index])
                        
                        // Small delete button for each block
                        Button {
                            deleteBlock(at: index)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.5))
                        }
                        .padding(.top, 8)
                    }
                }
                
                // 3. Add Block Menu (The "Plus" Button)
                Menu {
                    ButtonLabel(title: "Text", icon: "text.alignleft", action: { addBlock(.text) })
                    ButtonLabel(title: "Heading", icon: "pencil", action: { addBlock(.heading) })
                    ButtonLabel(title: "Code", icon: "chevron.left.forwardslash.chevron.right", action: { addBlock(.code) })
                    ButtonLabel(title: "Math", icon: "x.squareroot", action: { addBlock(.calculation) })
                    // We handle image differently (it triggers photo picker)
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Block")
                    }
                    .foregroundColor(.blue) // DESIGN: Action color
                    .padding()
                }
                
                // Separate Photo Picker
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    HStack {
                        Image(systemName: "photo")
                        Text("Add Image")
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        // Logic to load the image data
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            var newBlock = NoteBlock.empty(type: .image)
                            newBlock.imageData = data
                            note.blocks.append(newBlock)
                            selectedItem = nil // Reset picker
                        }
                    }
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
        .onDisappear {
            // Auto-save when leaving the screen
            store.updateNote(note)
        }
    }
    
    // --- Helper Functions ---
    
    // Decides which view to show based on block type
    @ViewBuilder
    func renderBlock(binding: Binding<NoteBlock>) -> some View {
        switch binding.wrappedValue.type {
        case .text:
            TextBlockView(text: binding.content)
        case .heading:
            HeadingBlockView(text: binding.content)
        case .code:
            CodeBlockView(code: binding.content)
        case .calculation:
            CalculationBlockView(equation: binding.content)
        case .image:
            ImageBlockView(imageData: binding.wrappedValue.imageData)
        }
    }
    
    func addBlock(_ type: BlockType) {
        withAnimation {
            note.blocks.append(NoteBlock.empty(type: type))
        }
    }
    
    func deleteBlock(at index: Int) {
        withAnimation {
            note.blocks.remove(at: index)
        }
    }
}

// Simple helper for menu buttons
struct ButtonLabel: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
        }
    }
}
