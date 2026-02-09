//
//  NewTextNoteSheet.swift
//  NotesLab
//
//  Created by Andrew Choi on 2/4/26.
//

import SwiftUI

struct NewTextNoteSheet: View {
    let editingNote: Note?
    var onSave: (Note) -> Void
    var onCancel: () -> Void

    @State private var text: String = ""
    @State private var hashtags: [String] = []
    @State private var newTag = ""
    @State private var showingTagInput = false

    @State private var isBold = false
    @State private var isItalic = false
    @State private var useSerif = false

    private let maxTextLength = 10000

    init(editingNote: Note? = nil, onSave: @escaping (Note) -> Void, onCancel: @escaping () -> Void) {
        self.editingNote = editingNote
        self.onSave = onSave
        self.onCancel = onCancel

        if let note = editingNote,
           let firstBlock = note.blocks.first(where: { $0.type == .text }) {
            _text = State(initialValue: firstBlock.content)
            _hashtags = State(initialValue: firstBlock.hashtags)
            _isBold = State(initialValue: firstBlock.isBold)
            _isItalic = State(initialValue: firstBlock.isItalic)
            _useSerif = State(initialValue: firstBlock.useSerif)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text(editingNote == nil ? "Create Text Note" : "Edit Text Note")
                .font(.headline)
                .padding(.top, 8)

            // Formatting buttons
            HStack(spacing: 16) {
                Button { isBold.toggle() } label: {
                    Text("B")
                        .fontWeight(.bold)
                        .foregroundColor(isBold ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                        .background(isBold ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                }

                Button { isItalic.toggle() } label: {
                    Text("I")
                        .italic()
                        .foregroundColor(isItalic ? .primary : .secondary)
                        .frame(width: 32, height: 32)
                        .background(isItalic ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                }

                Menu {
                    Button("Standard") { useSerif = false }
                    Button("Serif") { useSerif = true }
                } label: {
                    Text("Aa")
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }

                Spacer()
            }

            // Text editor
            TextEditor(text: $text)
                .font(currentFont)
                .frame(minHeight: 140, maxHeight: 180)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .onChange(of: text) { newValue in
                    if newValue.count > maxTextLength {
                        text = String(newValue.prefix(maxTextLength))
                    }
                }

            // Tags
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tags")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        showingTagInput.toggle()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }

                if !hashtags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(hashtags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        if let idx = hashtags.firstIndex(of: tag) {
                                            hashtags.remove(at: idx)
                                        }
                                    }
                            }
                        }
                    }
                }
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)

                Button(editingNote == nil ? "Create Note" : "Save Changes") {
                    saveNote()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .alert("Add Tag", isPresented: $showingTagInput) {
            TextField("Tag name", text: $newTag)
            Button("Cancel", role: .cancel) {
                newTag = ""
            }
            Button("Add") {
                addTag()
            }
        }
    }


    private var currentFont: Font {
        var base: Font = useSerif
            ? .system(size: 16, design: .serif)
            : .system(size: 16, design: .default)

        if isBold && isItalic {
            base = base.weight(.bold).italic()
        } else if isBold {
            base = base.weight(.bold)
        } else if isItalic {
            base = base.italic()
        }
        return base
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50 else { return }
        hashtags.append(trimmed)
        newTag = ""
    }
    
    private func saveNote() {
        let block = NoteBlock(
            id: editingNote?.blocks.first?.id ?? UUID(),
            type: .text,
            content: text,
            hashtags: hashtags,
            createdAt: editingNote?.blocks.first?.createdAt ?? Date(),
            imageData: nil,
            isBold: isBold,
            isItalic: isItalic,
            useSerif: useSerif
        )
        
        let note = Note(
            id: editingNote?.id ?? UUID(),
            title: editingNote?.title ?? "",
            icon: editingNote?.icon ?? "📄",
            date: Date(),
            blocks: [block],
            cardColorHex: editingNote?.cardColorHex ?? Note.randomCardColor()
        )
        
        onSave(note)
    }
}
