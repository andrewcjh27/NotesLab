//
//  NoteEditorView.swift
//  NotesLab
//

import SwiftUI
import UniformTypeIdentifiers

struct NoteEditorView: View {
    @State private var note: Note
    @ObservedObject var store: NotesStore

    @State private var previousIcon: String = ""
    @State private var draggedBlock: NoteBlock?

    @FocusState private var isInputActive: Bool

    @State private var editingBlockIndex: Int? = nil
    @State private var showingEditTextFlow = false

    init(note: Note, store: NotesStore) {
        _note = State(initialValue: note)
        self.store = store
        _previousIcon = State(initialValue: note.icon)
    }

    var body: some View {
        ScrollView {
            content
        }
        .background(Color(.systemBackground))
        .onTapGesture {
            isInputActive = false
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
        .toolbar { toolbarContent }
        .onDisappear {
            store.updateNote(note)
        }
        .onChange(of: note) { _ in
            store.updateNote(note)
        }
        .sheet(isPresented: $showingEditTextFlow) {
            if let index = editingBlockIndex, index < note.blocks.count {
                let block = note.blocks[index]
                NewTextNoteSheet(
                    editingNote: Note(
                        id: note.id,
                        title: note.title,
                        icon: note.icon,
                        date: note.date,
                        blocks: [block]
                    ),
                    onSave: { updatedNote in
                        if let updatedBlock = updatedNote.blocks.first {
                            note.blocks[index] = updatedBlock
                            store.updateNote(note)
                        }
                    },
                    onCancel: {
                        showingEditTextFlow = false
                    }
                )
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            blocksList
            Spacer(minLength: 80)
        }
        .padding()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            TextField("Icon", text: $note.icon)
                .font(.system(size: 40))
                .frame(width: 50)
                .multilineTextAlignment(.center)
                .focused($isInputActive)
                .onChange(of: note.icon) { newValue in
                    guard !newValue.isEmpty else { return }
                    let lastChar = String(newValue.suffix(1))
                    if lastChar.containsValidEmoji {
                        note.icon = lastChar
                        previousIcon = lastChar
                    } else {
                        note.icon = previousIcon
                    }
                }
                .accessibilityLabel("Note icon")
        }
        .padding(.bottom)
    }

    private var blocksList: some View {
        VStack(spacing: 0) {
            ForEach($note.blocks) { $block in
                let blockID = block.id
                let blockItem = block

                renderBlock(binding: $block)
                    .focused($isInputActive)
                    .overlay(
                        draggedBlock?.id == blockItem.id ?
                        Color.white.opacity(0.01) : Color.clear
                    )
                    .padding(.vertical, 4)
                    .padding(.horizontal, 4)
                    .background(Color(.secondarySystemBackground))
                    .contentShape(Rectangle())
                    .onDrag {
                        draggedBlock = blockItem
                        return NSItemProvider(object: blockID.uuidString as NSString)
                    } preview: {
                        HStack(alignment: .top) {
                            let textToShow = previewText(for: blockItem)

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
                    .onDrop(
                        of: [UTType.text],
                        delegate: DropViewDelegate(
                            item: blockItem,
                            items: $note.blocks,
                            draggedItem: $draggedBlock
                        )
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteBlock(blockID)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            HStack(spacing: 8) {
                Button {
                    sendAction(#selector(RichTextView.toggleBold))
                } label: {
                    Image(systemName: "bold")
                }
                .accessibilityLabel("Toggle bold")

                Button {
                    sendAction(#selector(RichTextView.toggleItalic))
                } label: {
                    Image(systemName: "italic")
                }
                .accessibilityLabel("Toggle italic")

                Menu {
                    Button("Standard") {
                        sendAction(#selector(RichTextView.setStandard))
                    }
                    Button("Serif") {
                        sendAction(#selector(RichTextView.setSerif))
                    }
                    Button("Mono") {
                        sendAction(#selector(RichTextView.setMono))
                    }
                } label: {
                    Image(systemName: "textformat")
                }
                .accessibilityLabel("Font style")
            }
        }
    }

    private func sendAction(_ selector: Selector) {
        UIApplication.shared.sendAction(selector, to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    private func renderBlock(binding: Binding<NoteBlock>) -> some View {
        switch binding.wrappedValue.type {
        case .text:
            VStack(alignment: .leading, spacing: 6) {
                TextEditor(text: binding.content)
                    .font(.body)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .disabled(true)
                    .onTapGesture {
                        if let index = note.blocks.firstIndex(where: { $0.id == binding.wrappedValue.id }) {
                            editingBlockIndex = index
                            showingEditTextFlow = true
                        }
                    }

                BlockFooterView(
                    hashtags: binding.hashtags,
                    createdAt: binding.wrappedValue.createdAt
                )
            }

        case .heading:
            HeadingBlockView(
                text: binding.content,
                hashtags: binding.hashtags,
                createdAt: binding.wrappedValue.createdAt
            )

        case .code:
            CodeBlockView(
                code: binding.content,
                hashtags: binding.hashtags,
                createdAt: binding.wrappedValue.createdAt
            )

        case .calculation:
            CalculationBlockView(
                equation: binding.content,
                hashtags: binding.hashtags,
                createdAt: binding.wrappedValue.createdAt
            )

        case .image:
            VStack(alignment: .leading, spacing: 8) {
                // Inline ImageBlockView to avoid scope issues
                VStack(alignment: .leading, spacing: 6) {
                    if let data = binding.wrappedValue.imageData,
                       let uiImage = downsampleImage(data: data, to: CGSize(width: 500, height: 500)) {

                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .clipped()
                            .cornerRadius(8)
                            .accessibilityLabel("Block image")

                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 220)
                            .overlay(
                                Text("No Image").foregroundColor(.gray)
                            )
                            .cornerRadius(8)
                            .accessibilityLabel("No image")
                    }

                    BlockFooterView(hashtags: binding.hashtags, createdAt: binding.wrappedValue.createdAt)
                }
                
                TextField("Description (optional)", text: binding.content)
                    .font(.subheadline)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func deleteBlock(_ id: UUID) {
        withAnimation {
            note.blocks.removeAll { $0.id == id }
        }
    }

    private func previewText(for block: NoteBlock) -> String {
        switch block.type {
        case .text, .heading, .code:
            return stripHTML(from: block.content)
        default:
            return block.content
        }
    }

    private func stripHTML(from html: String) -> String {
        guard html.contains("<") else { return html }
        var plain = html
        plain = plain.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        let trimmed = plain.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No text" : trimmed
    }
    
    private func downsampleImage(data: Data, to targetSize: CGSize) -> UIImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: max(targetSize.width, targetSize.height),
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Helpers

extension String {
    var containsValidEmoji: Bool {
        guard !isEmpty else { return false }
        
        // Get the first grapheme cluster (what users see as one character)
        let firstGrapheme = String(self.prefix(1))
        
        // Check if it contains emoji
        return firstGrapheme.unicodeScalars.contains { scalar in
            scalar.properties.isEmoji &&
            scalar.value > 0x238C // Exclude things like # and *
        }
    }
}

struct DropViewDelegate: DropDelegate {
    let item: NoteBlock
    @Binding var items: [NoteBlock]
    @Binding var draggedItem: NoteBlock?

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
    
    func dropExited(info: DropInfo) {
        draggedItem = nil
    }

    func dropEntered(info: DropInfo) {
        guard let draggedItem,
              draggedItem.id != item.id,
              let from = items.firstIndex(where: { $0.id == draggedItem.id }),
              let to = items.firstIndex(where: { $0.id == item.id }) else { return }

        withAnimation {
            items.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
