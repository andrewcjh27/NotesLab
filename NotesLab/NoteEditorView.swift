//
//  NoteEditorView.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/26/26.
//

import SwiftUI
import PhotosUI
import Foundation
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @State private var note: Note
    @ObservedObject var store: NotesStore
    @State private var selectedItem: PhotosPickerItem? = nil
    
    @State private var previousIcon: String = ""
    @State private var draggedBlock: NoteBlock?
    @FocusState private var isInputActive: Bool
    
    init(note: Note, store: NotesStore) {
        self._note = State(initialValue: note)
        self.store = store
        self._previousIcon = State(initialValue: note.icon)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Title & Icon Area
                HStack(alignment: .center, spacing: 12) {
                    TextField("Icon", text: $note.icon)
                        .font(.system(size: 40))
                        .frame(width: 50)
                        .multilineTextAlignment(.center)
                        .focused($isInputActive)
                        .onChange(of: note.icon) { newValue in
                            if newValue.isEmpty { return }
                            let lastChar = String(newValue.suffix(1))
                            if lastChar.containsOnlyEmoji {
                                note.icon = lastChar
                                previousIcon = lastChar
                            } else {
                                note.icon = previousIcon
                            }
                        }
                    
                    TextField("Note Title", text: $note.title)
                        .font(.largeTitle.bold())
                        .focused($isInputActive)
                }
                .padding(.bottom)
                
                // Render all blocks
                ForEach($note.blocks) { $block in
                    let blockID = $block.wrappedValue.id
                    let blockItem = $block.wrappedValue
                    
                    HStack(alignment: .top) {
                        renderBlock(binding: $block)
                            .focused($isInputActive)
                            // Invisible shield only appears when THIS specific block is being dragged
                            .overlay(
                                draggedBlock?.id == blockItem.id ? Color.white.opacity(0.01) : Color.clear
                            )
                        
                        VStack(spacing: 4) {
                            Button {
                                deleteBlock(blockID)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: 32, height: 32)
                            }
                            
                            Image(systemName: "line.3.horizontal")
                                .font(.title3)
                                .foregroundColor(.gray.opacity(0.3))
                                .frame(width: 44, height: 44)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    
                    // ATTACH DRAG TO THE WHOLE BLOCK
                    .onDrag {
                        self.draggedBlock = blockItem
                        return NSItemProvider(object: blockID.uuidString as NSString)
                    } preview: {
                        // FIX: Explicitly define the drag preview to hide the UUID text.
                        // This renders a clean white card containing the block text.
                        HStack(alignment: .top) {
                            // CLEANUP: Use stripHTML to show clean text instead of raw HTML code
                            let textToShow = blockItem.type == .text ? stripHTML(from: blockItem.content) : blockItem.content
                            Text(textToShow.isEmpty ? "Block" : textToShow)
                                .font(.body)
                                .lineLimit(3)
                                .padding()
                            Spacer()
                        }
                        .frame(width: UIScreen.main.bounds.width - 60)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 5)
                    }
                    .onDrop(of: [UTType.text], delegate: DropViewDelegate(item: blockItem, items: $note.blocks, draggedItem: $draggedBlock))
                }
                
                Spacer(minLength: 80)
            }
            .padding()
        }
        .onTapGesture {
            isInputActive = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        // ... Toolbars ...
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    Button { sendAction(#selector(RichTextView.toggleBold)) } label: { Image(systemName: "bold") }
                    Button { sendAction(#selector(RichTextView.toggleItalic)) } label: { Image(systemName: "italic") }
                    Menu {
                        Button("Standard") { sendAction(#selector(RichTextView.setStandard)) }
                        Button("Serif") { sendAction(#selector(RichTextView.setSerif)) }
                        Button("Mono") { sendAction(#selector(RichTextView.setMono)) }
                    } label: {
                        Image(systemName: "textformat")
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 20) {
                ToolButton(icon: "text.alignleft", label: "Text") { addBlock(.text) }
                ToolButton(icon: "number", label: "Math") { addBlock(.calculation) }
                ToolButton(icon: "chevron.left.forwardslash.chevron.right", label: "Code") { addBlock(.code) }
                
                Spacer()
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(.indigo)
                        .frame(width: 44, height: 44)
                        .background(Color.indigo.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(Color.gray.opacity(0.2)),
                alignment: .top
            )
        }
        .onDisappear { store.updateNote(note) }
        .onChange(of: note) { _ in store.updateNote(note) }
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
    }
    
    func sendAction(_ selector: Selector) {
        UIApplication.shared.sendAction(selector, to: nil, from: nil, for: nil)
    }
    
    @ViewBuilder
    func renderBlock(binding: Binding<NoteBlock>) -> some View {
        switch binding.wrappedValue.type {
        case .text: TextBlockView(text: binding.content)
        case .heading: HeadingBlockView(text: binding.content)
        case .code: CodeBlockView(code: binding.content)
        case .calculation: CalculationBlockView(equation: binding.content)
        case .image: ImageBlockView(imageData: binding.wrappedValue.imageData)
        }
    }
    
    func addBlock(_ type: BlockType) {
        withAnimation {
            note.blocks.append(NoteBlock.empty(type: type))
        }
    }
    
    func deleteBlock(_ id: UUID) {
        withAnimation {
            note.blocks.removeAll { $0.id == id }
        }
    }
    
    // NEW: Helper to clean up HTML for previews
    // This simple regex stripper is fast and safe for preview purposes
    func stripHTML(from text: String) -> String {
        guard text.contains("<") else { return text }
        var plain = text
        // Remove style and head blocks first to avoid showing CSS code
        plain = plain.replacingOccurrences(of: "(?s)<style.*?>.*?</style>", with: "", options: .regularExpression)
        plain = plain.replacingOccurrences(of: "(?s)<head.*?>.*?</head>", with: "", options: .regularExpression)
        // Remove all other tags
        plain = plain.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Basic entity decoding
        plain = plain.replacingOccurrences(of: "&nbsp;", with: " ")
        plain = plain.replacingOccurrences(of: "&lt;", with: "<")
        plain = plain.replacingOccurrences(of: "&gt;", with: ">")
        plain = plain.replacingOccurrences(of: "&amp;", with: "&")
        
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No additional text" : trimmed
    }
}

// ... Extensions and Helpers ...
extension String {
    var containsOnlyEmoji: Bool {
        guard !isEmpty else { return false }
        return unicodeScalars.allSatisfy { scalar in
            scalar.properties.isEmoji
        }
    }
}

struct ToolButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.1))
                .clipShape(Circle())
        }
    }
}

struct DropViewDelegate: DropDelegate {
    let item: NoteBlock
    @Binding var items: [NoteBlock]
    @Binding var draggedItem: NoteBlock?

    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem = self.draggedItem else { return }
        if draggedItem.id != item.id {
            if let from = items.firstIndex(where: { $0.id == draggedItem.id }),
               let to = items.firstIndex(where: { $0.id == item.id }) {
                withAnimation {
                    items.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                }
            }
        }
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
