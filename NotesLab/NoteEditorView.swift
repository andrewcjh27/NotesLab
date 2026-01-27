//
//  NoteEditorView.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import SwiftUI
import PhotosUI
import Foundation

struct NoteEditorView: View {
    @State private var note: Note
    @ObservedObject var store: NotesStore
    @State private var selectedItem: PhotosPickerItem? = nil
    
    init(note: Note, store: NotesStore) {
        self._note = State(initialValue: note)
        self.store = store
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Title Area
                TextField("Note Title", text: $note.title)
                    .font(.largeTitle.bold())
                    .padding(.bottom)
                
                // Render all blocks
                ForEach($note.blocks.indices, id: \.self) { index in
                    HStack(alignment: .top) {
                        renderBlock(binding: $note.blocks[index])
                        
                        // Delete Block Button
                        Button {
                            deleteBlock(at: index)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.red.opacity(0.3))
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Add Block Menu
                Menu {
                    ButtonLabel(title: "Text", icon: "text.alignleft", action: { addBlock(.text) })
                    ButtonLabel(title: "Heading", icon: "pencil", action: { addBlock(.heading) })
                    ButtonLabel(title: "Code", icon: "chevron.left.forwardslash.chevron.right", action: { addBlock(.code) })
                    ButtonLabel(title: "Math", icon: "x.squareroot", action: { addBlock(.calculation) })
                } label: {
                    Label("Add Block", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                
                // Image Picker Button
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Add Image", systemImage: "photo")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            var newBlock = NoteBlock.empty(type: .image)
                            newBlock.imageData = data
                            note.blocks.append(newBlock)
                            selectedItem = nil
                        }
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        // 1. Keep the old save (just in case the user exits quickly)
        .onDisappear {
            store.updateNote(note)
        }
        // 2. AUTO-SAVE: This triggers every time 'note' changes
        .onChange(of: note) { _ in
            store.updateNote(note)
        }
    }
    
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

struct ButtonLabel: View {
    let title: String
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Label(title, systemImage: icon) }
    }
}
