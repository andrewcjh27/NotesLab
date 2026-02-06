import SwiftUI
import PhotosUI

struct NewImageNoteSheet: View {
    let editingNote: Note?
    var onSave: (Note) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage? = nil
    @State private var caption: String = ""
    @State private var hashtags: [String] = []
    @State private var newTag = ""
    @State private var showingTagInput = false

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isLoading = false

    init(editingNote: Note? = nil, onSave: @escaping (Note) -> Void) {
        self.editingNote = editingNote
        self.onSave = onSave

        if let note = editingNote,
           let firstBlock = note.blocks.first(where: { $0.type == .image }) {
            _hashtags = State(initialValue: firstBlock.hashtags)
            _caption = State(initialValue: firstBlock.content)

            if let data = firstBlock.imageData,
               let ui = UIImage(data: data) {
                _image = State(initialValue: ui)
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(editingNote == nil ? "Create Image Note" : "Edit Image Note")
                .font(.headline)
                .padding(.top, 8)

            // Image preview / picker
            ZStack {
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 180)
                        .cornerRadius(10)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 140)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 26))
                                    .foregroundColor(.blue)
                                Text("Tap to choose image")
                                    .font(.system(.caption, design: .serif))
                                    .foregroundColor(.secondary)
                            }
                        )
                }

                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                }
            }
            .onTapGesture {
                // open picker via binding
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Text("Choose Photo")
                    .font(.system(.body, design: .serif))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .onChange(of: pickerItem) { newValue in
                guard let item = newValue else { return }
                isLoading = true
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        await MainActor.run {
                            self.image = ui
                            self.isLoading = false
                        }
                    } else {
                        await MainActor.run { self.isLoading = false }
                    }
                }
            }

            // Description
            TextField("Description (optional)", text: $caption)
                .textFieldStyle(.roundedBorder)

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
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.bordered)

                Button(editingNote == nil ? "Create Note" : "Save Changes") {
                    saveNote()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
                .disabled(image == nil && editingNote == nil)
            }
            .padding(.bottom, 8)
        }
        .padding()
        .alert("Add Tag", isPresented: $showingTagInput) {
            TextField("Tag name", text: $newTag)
            Button("Cancel", role: .cancel) { newTag = "" }
            Button("Add") { addTag() }
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50 else { return }
        hashtags.append(trimmed)
        newTag = ""
    }

    private func saveNote() {
        var data: Data? = nil
        if let ui = image {
            data = ui.jpegData(compressionQuality: 0.9)
        } else if let note = editingNote,
                  let firstBlock = note.blocks.first(where: { $0.type == .image }) {
            data = firstBlock.imageData
        }

        let block = NoteBlock(
            id: editingNote?.blocks.first?.id ?? UUID(),
            type: .image,
            content: caption,
            hashtags: hashtags,
            createdAt: editingNote?.blocks.first?.createdAt ?? Date(),
            imageData: data,
            isBold: false,
            isItalic: false,
            useSerif: false
        )

        let note = Note(
            id: editingNote?.id ?? UUID(),
            title: editingNote?.title ?? "",
            icon: editingNote?.icon ?? "🖼",
            date: Date(),
            blocks: [block]
        )

        onSave(note)
        dismiss()
    }
}
