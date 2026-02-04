import SwiftUI
import UIKit
import PhotosUI

struct ContentView: View {
    @StateObject private var store = NotesStore()
    @State private var navigationPath = NavigationPath()

    // Search & filter
    @State private var searchText = ""
    @State private var filterType: BlockType? = nil
    @State private var sortOption: SortOption = .recent

    enum SortOption: String, CaseIterable {
        case recent = "Recently Added"
        case alphabetical = "Alphabetical"
    }

    // Creation
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    // Text note alerts (new + edit)
    @State private var showingTextAlert = false          // 1st alert: main text
    @State private var textAlertValue = ""
    @State private var editingTextNote: Note? = nil      // nil = new, non-nil = editing

    @State private var showingMetaAlert = false          // 2nd alert: description + hashtags
    @State private var descriptionValue = ""
    @State private var hashtagsValue = ""

    // 2‑column grid
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    // MARK: - Filtered notes

    var filteredNotes: [Note] {
        let filtered = store.notes.filter { note in
            doesNoteMatch(note)
        }

        return filtered.sorted {
            switch sortOption {
            case .recent:
                return $0.date > $1.date
            case .alphabetical:
                return $0.title < $1.title
            }
        }
    }

    private func doesNoteMatch(_ note: Note) -> Bool {
        let searchMatch: Bool
        if searchText.isEmpty {
            searchMatch = true
        } else {
            let matchesTitle = note.title.localizedCaseInsensitiveContains(searchText)

            let allTags = note.blocks.flatMap { $0.hashtags }
            let matchesTag = allTags.contains {
                $0.localizedCaseInsensitiveContains(searchText)
            }

            let blockContentMatch = note.blocks.contains {
                $0.content.localizedCaseInsensitiveContains(searchText)
            }

            searchMatch = matchesTitle || matchesTag || blockContentMatch
        }

        let typeMatch: Bool
        if let type = filterType {
            typeMatch = note.blocks.contains { $0.type == type }
        } else {
            typeMatch = true
        }

        return searchMatch && typeMatch
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !searchText.isEmpty {
                        Text("Searching for: \(searchText)")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredNotes) { note in
                            let isPureText = note.blocks.allSatisfy { $0.type == .text }

                            if isPureText {
                                // Text-only notes: edit via alerts, no navigation
                                Button {
                                    editingTextNote = note

                                    if let firstText = note.blocks.first(where: { $0.type == .text }) {
                                        textAlertValue = firstText.content
                                    } else {
                                        textAlertValue = ""
                                    }

                                    descriptionValue = note.title
                                    let tags = Array(Set(note.blocks.flatMap { $0.hashtags })).sorted()
                                    hashtagsValue = tags.joined(separator: " ")

                                    showingTextAlert = true
                                } label: {
                                    NoteCardView(note: note)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteNote(note)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        // Edit main text via alerts
                                        editingTextNote = note
                                        if let firstText = note.blocks.first(where: { $0.type == .text }) {
                                            textAlertValue = firstText.content
                                        } else {
                                            textAlertValue = ""
                                        }
                                        descriptionValue = note.title
                                        let tags = Array(Set(note.blocks.flatMap { $0.hashtags })).sorted()
                                        hashtagsValue = tags.joined(separator: " ")
                                        showingTextAlert = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }
                            } else {
                                // Other notes still use big editor
                                NavigationLink(value: note) {
                                    NoteCardView(note: note)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteNote(note)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }

                                    Button {
                                        // Edit main text via alerts, even for non-text notes if desired
                                        editingTextNote = note
                                        if let firstText = note.blocks.first(where: { $0.type == .text }) {
                                            textAlertValue = firstText.content
                                        } else {
                                            textAlertValue = ""
                                        }
                                        descriptionValue = note.title
                                        let tags = Array(Set(note.blocks.flatMap { $0.hashtags })).sorted()
                                        hashtagsValue = tags.joined(separator: " ")
                                        showingTextAlert = true
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Canvas")
                        .font(.system(.title, design: .serif))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search my canvas")
            .navigationDestination(for: Note.self) { note in
                NoteEditorView(note: note, store: store)
            }
            .toolbar {
                // Left toolbar
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort By", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }

                        Divider()

                        Button { filterType = nil } label: {
                            Label("All Notes", systemImage: "square.grid.2x2")
                        }
                        Button { filterType = .text } label: {
                            Label("Text", systemImage: "text.alignleft")
                        }
                        Button { filterType = .image } label: {
                            Label("Images", systemImage: "photo")
                        }
                        Button { filterType = .code } label: {
                            Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(.primary)
                    }
                }

                // Right toolbar
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // New text note via alerts
                        Button {
                            editingTextNote = nil
                            textAlertValue = ""
                            descriptionValue = ""
                            hashtagsValue = ""
                            showingTextAlert = true
                        } label: {
                            Label("Text Note", systemImage: "text.alignleft")
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Image Note", systemImage: "photo")
                        }

                        Button { createAndNavigate(type: .code) } label: {
                            Label("Code Note", systemImage: "chevron.left.forwardslash.chevron.right")
                        }

                        Button { createAndNavigate(type: .calculation) } label: {
                            Label("Math Note", systemImage: "function")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { handlePhotoChange($0) }
            // 1st alert: main text
            .alert("Text Note", isPresented: $showingTextAlert) {
                TextField("Text", text: $textAlertValue)

                Button("Cancel", role: .cancel) {
                    editingTextNote = nil
                    textAlertValue = ""
                    descriptionValue = ""
                    hashtagsValue = ""
                }

                Button("Next") {
                    showingMetaAlert = true
                }
            }
            // 2nd alert: description + hashtags, performs save
            .alert("Details", isPresented: $showingMetaAlert) {
                TextField("Description", text: $descriptionValue)
                TextField("Hashtags (space separated)", text: $hashtagsValue)

                Button("Cancel", role: .cancel) {
                    editingTextNote = nil
                    descriptionValue = ""
                    hashtagsValue = ""
                }

                Button(editingTextNote == nil ? "Add" : "Save") {
                    let tags = hashtagsValue
                        .split(whereSeparator: { $0.isWhitespace })
                        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }

                    if var note = editingTextNote {
                        // Editing existing note
                        if let idx = note.blocks.firstIndex(where: { $0.type == .text }) {
                            note.blocks[idx].content = textAlertValue
                            note.blocks[idx].hashtags = tags
                        } else {
                            let block = NoteBlock(
                                id: UUID(),
                                type: .text,
                                content: textAlertValue,
                                hashtags: tags,
                                createdAt: Date(),
                                imageData: nil,
                                isBold: false,
                                isItalic: false,
                                useSerif: false
                            )
                            note.blocks.append(block)
                        }
                        note.title = descriptionValue
                        store.updateNote(note)
                    } else {
                        // Creating new text note
                        let block = NoteBlock(
                            id: UUID(),
                            type: .text,
                            content: textAlertValue,
                            hashtags: tags,
                            createdAt: Date(),
                            imageData: nil,
                            isBold: false,
                            isItalic: false,
                            useSerif: false
                        )

                        let note = Note(
                            id: UUID(),
                            title: descriptionValue,
                            icon: "📄",
                            date: Date(),
                            blocks: [block]
                        )

                        store.notes.insert(note, at: 0)
                        store.updateNote(note)
                    }

                    editingTextNote = nil
                    textAlertValue = ""
                    descriptionValue = ""
                    hashtagsValue = ""
                }
            }
        }
    }

    // MARK: - Helpers

    private func createAndNavigate(type: BlockType) {
        let note = store.createNote(with: type)
        navigationPath.append(note)
    }

    private func handlePhotoChange(_ newItem: PhotosPickerItem?) {
        guard let newItem else { return }
        Task {
            if let data = try? await newItem.loadTransferable(type: Data.self) {
                createImageNoteAndNavigate(data: data)
            }
            selectedPhotoItem = nil
        }
    }

    private func createImageNoteAndNavigate(data: Data) {
        var note = store.createNote(with: .image)

        if note.blocks.isEmpty {
            let block = NoteBlock(
                id: UUID(),
                type: .image,
                content: "",
                hashtags: [],
                createdAt: Date(),
                imageData: data,
                isBold: false,
                isItalic: false,
                useSerif: false
            )
            note.blocks.append(block)
        } else {
            note.blocks[0].imageData = data
            note.blocks[0].content = ""
        }

        store.updateNote(note)
        navigationPath.append(note)
    }
}

// MARK: - Note card

struct NoteCardView: View {
    let note: Note

    private var firstTextLikeBlock: NoteBlock? {
        note.blocks.first(where: { $0.type == .text || $0.type == .heading || $0.type == .code })
    }

    private var displayTitle: String {
        let trimmedTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        if let textBlock = firstTextLikeBlock {
            let plain = stripHTML(from: textBlock.content)
            if !plain.isEmpty { return plain }
        }

        if let imgBlock = note.blocks.first(where: { $0.type == .image }) {
            let desc = imgBlock.content
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "\n")
                .first
                .map(String.init) ?? ""
            if !desc.isEmpty { return desc }
        }

        let tags = Array(Set(note.blocks.flatMap { $0.hashtags })).sorted()
        if !tags.isEmpty {
            return tags.map { "#\($0)" }.joined(separator: " ")
        }

        return "Untitled"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let firstImageBlock = note.blocks.first(where: { $0.type == .image }),
               let data = firstImageBlock.imageData,
               let uiImage = UIImage(data: data) {

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .clipped()
                    .contentShape(Rectangle())
            } else {
                ZStack {
                    Color.white
                    Text(getPreviewText())
                        .font(firstTextLikeBlock.map(previewFont(for:)) ?? .system(size: 20, design: .serif))
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .truncationMode(.tail)
                        .foregroundColor(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 150)
            }

            if let imgBlock = note.blocks.first(where: { $0.type == .image }),
               !imgBlock.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(imgBlock.content)
                    .font(.footnote)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack {
                    Text(note.date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.gray)

                    Spacer()

                    if !note.blocks.isEmpty {
                        Image(systemName: "doc.text")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }

                    let tags = Array(Set(note.blocks.flatMap { $0.hashtags })).sorted()
                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(tags.prefix(3), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color.indigo.opacity(0.1))
                                        .foregroundColor(.indigo)
                                        .cornerRadius(4)
                                }
                            }
                            .frame(height: 20)
                        }
                    }
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
    }

    private func getPreviewText() -> String {
        if let block = firstTextLikeBlock {
            return stripHTML(from: block.content)
        }
        return "New Note"
    }

    private func stripHTML(from text: String) -> String {
        var plain = text
        plain = plain.replacingOccurrences(
            of: "(?is)<style[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )
        plain = plain.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        plain = plain.replacingOccurrences(of: "&nbsp;", with: " ")
        plain = plain.replacingOccurrences(of: "&amp;", with: "&")
        return plain.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func previewFont(for block: NoteBlock) -> Font {
        // Default serif for previews
        var base: Font = .system(size: 20, design: .serif)

        if block.isBold && block.isItalic {
            base = base.weight(.bold).italic()
        } else if block.isBold {
            base = base.weight(.bold)
        } else if block.isItalic {
            base = base.italic()
        }
        return base
    }
}

