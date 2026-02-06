import SwiftUI

struct NewCodeNoteSheet: View {
    let editingNote: Note?
    var onSave: (Note) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var hashtags: [String] = []
    @State private var newTag = ""
    @State private var showingTagInput = false

    private let maxCodeLength = 50000

    init(editingNote: Note? = nil, onSave: @escaping (Note) -> Void) {
        self.editingNote = editingNote
        self.onSave = onSave

        if let note = editingNote,
           let firstBlock = note.blocks.first(where: { $0.type == .code }) {
            _code = State(initialValue: firstBlock.content)
            _hashtags = State(initialValue: firstBlock.hashtags)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text(editingNote == nil ? "Create Code Note" : "Edit Code Note")
                .font(.headline)
                .padding(.top, 8)

            // Code editor
            TextEditor(text: $code)
                .font(.system(size: 14, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(hex: "1E1E1E"))
                .foregroundColor(Color(hex: "D4D4D4"))
                .cornerRadius(8)
                .frame(minHeight: 120, maxHeight: 180)
                .padding(4)
                .onChange(of: code) { newValue in
                    if newValue.count > maxCodeLength {
                        code = String(newValue.prefix(maxCodeLength))
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
                                    .background(Color(hex: "569CD6").opacity(0.2))
                                    .foregroundColor(Color(hex: "569CD6"))
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
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)

                Button(editingNote == nil ? "Create Note" : "Save Changes") {
                    saveNote()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.bottom, 8)
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

    // MARK: - Helpers

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50 else { return }
        hashtags.append(trimmed)
        newTag = ""
    }

    private func saveNote() {
        let block = NoteBlock(
            id: editingNote?.blocks.first?.id ?? UUID(),
            type: .code,
            content: code,
            hashtags: hashtags,
            createdAt: editingNote?.blocks.first?.createdAt ?? Date(),
            imageData: nil,
            isBold: false,
            isItalic: false,
            useSerif: false
        )

        let note = Note(
            id: editingNote?.id ?? UUID(),
            title: editingNote?.title ?? "",
            icon: editingNote?.icon ?? "💻",
            date: Date(),
            blocks: [block]
        )

        onSave(note)
        dismiss()
    }
}
