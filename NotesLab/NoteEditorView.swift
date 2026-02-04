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

    // Sheet-based text editing for existing blocks
    @State private var editingBlockIndex: Int? = nil
    @State private var showingEditTextFlow = false
    @State private var draftText = ""
    @State private var draftHashtags: [String] = []
    @State private var draftDescription = ""
    @State private var draftIsBold = false
    @State private var draftIsItalic = false
    @State private var draftUseSerif = false

    init(note: Note, store: NotesStore) {
        _note = State(initialValue: note)
        self.store = store
        _previousIcon = State(initialValue: note.icon)
    }

    // MARK: - Body

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
        // Sheet for editing existing text blocks
        .sheet(isPresented: $showingEditTextFlow) {
            if let index = editingBlockIndex {
                NewTextNoteSheet(
                    text: $draftText,
                    hashtags: $draftHashtags,
                    description: $draftDescription
                ) { text, tags, description, isBold, isItalic, useSerif in
                    note.blocks[index].content = text
                    note.blocks[index].hashtags = tags
                    note.blocks[index].isBold = isBold
                    note.blocks[index].isItalic = isItalic
                    note.blocks[index].useSerif = useSerif
                    store.updateNote(note)
                }
            }
        }
    }

    // MARK: - Subviews

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
                    if lastChar.containsOnlyEmoji {
                        note.icon = lastChar
                        previousIcon = lastChar
                    } else {
                        note.icon = previousIcon
                    }
                }

            // No title field anymore
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

                Button {
                    sendAction(#selector(RichTextView.toggleItalic))
                } label: {
                    Image(systemName: "italic")
                }

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
            }
        }
    }

    // MARK: - Actions

    private func sendAction(_ selector: Selector) {
        UIApplication.shared.sendAction(selector, to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    private func renderBlock(binding: Binding<NoteBlock>) -> some View {
        switch binding.wrappedValue.type {
        case .text:
            VStack(alignment: .leading, spacing: 6) {
                // Show text but edit via sheet when tapped
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
                            let b = note.blocks[index]
                            draftText = b.content
                            draftHashtags = b.hashtags
                            draftDescription = ""
                            draftIsBold = b.isBold
                            draftIsItalic = b.isItalic
                            draftUseSerif = b.useSerif
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
                ImageBlockView(
                    imageData: binding.wrappedValue.imageData,
                    hashtags: binding.hashtags,
                    createdAt: binding.wrappedValue.createdAt
                )
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

    // MARK: - Preview text + HTML helper

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
}

// MARK: - Helpers

extension String {
    var containsOnlyEmoji: Bool {
        guard !isEmpty else { return false }
        return unicodeScalars.allSatisfy { $0.properties.isEmoji }
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
