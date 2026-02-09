import SwiftUI

struct NewMathNoteSheet: View {
    let editingNote: Note?
    var onSave: (Note) -> Void
    var onCancel: () -> Void

    @State private var equation: String = ""
    @State private var hashtags: [String] = []
    @State private var newTag = ""
    @State private var showingTagInput = false

    init(editingNote: Note? = nil, onSave: @escaping (Note) -> Void, onCancel: @escaping () -> Void) {
        self.editingNote = editingNote
        self.onSave = onSave
        self.onCancel = onCancel

        if let note = editingNote,
           let firstBlock = note.blocks.first(where: { $0.type == .calculation }) {
            _equation = State(initialValue: firstBlock.content)
            _hashtags = State(initialValue: firstBlock.hashtags)
        }
    }

    // MARK: - Result

    var result: String {
        let cleanEq = equation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEq.isEmpty else { return "..." }

        // Allow digits, decimal point, basic operators, parentheses, and spaces
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        if cleanEq.rangeOfCharacter(from: allowed.inverted) != nil {
            return "?"
        }

        // Check for invalid endings
        if let last = cleanEq.last, "+-*/.".contains(last) {
            return "..."
        }

        let expression = NSExpression(format: cleanEq)
        if let value = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            let number = value.doubleValue
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 4
            formatter.minimumFractionDigits = 0
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: number)) ?? "?"
        } else {
            return "?"
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            Text(editingNote == nil ? "Create Math Note" : "Edit Math Note")
                .font(.headline)
                .padding(.top, 8)

            // Equation + result
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter equation (e.g. 5.5 + 10.2)", text: $equation)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .monospaced))

                HStack {
                    Text("=")
                        .font(.title3)
                        .foregroundColor(.secondary)

                    Text(result)
                        .font(.system(size: 24, design: .serif).weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .foregroundColor(.blue)

                    Spacer()
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
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
                .disabled(equation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .alert("Add Tag", isPresented: $showingTagInput) {
            TextField("Tag name", text: $newTag)
            Button("Cancel", role: .cancel) { newTag = "" }
            Button("Add") { addTag() }
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
            type: .calculation,
            content: equation,
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
            icon: editingNote?.icon ?? "🔢",
            date: Date(),
            blocks: [block],
            cardColorHex: editingNote?.cardColorHex ?? Note.randomCardColor()
        )

        onSave(note)
    }
}
