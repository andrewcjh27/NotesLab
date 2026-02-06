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

    // Creation sheets
    @State private var showingNewNoteTypeSheet = false
    @State private var showingTextSheet = false
    @State private var showingCodeSheet = false
    @State private var showingMathSheet = false
    @State private var showingImageSheet = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isLoadingPhoto = false

    // Editing
    @State private var editingNote: Note? = nil

    // 2-column grid
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    // Cache for stripped HTML
    @State private var previewCache: [UUID: String] = [:]

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
                            NavigationLink(value: note) {
                                NoteCardView(note: note, previewCache: $previewCache)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    editingNote = note
                                    navigationPath.append(note)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
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
                    Text("Nova")
                        .font(.system(.title, design: .serif))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search my novas")
            .navigationDestination(for: Note.self) { note in
                NoteEditorView(note: note, store: store)
            }
            // Centered popup for choosing note type
            .overlay {
                if showingNewNoteTypeSheet {
                    ZStack {
                        // Dim background
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showingNewNoteTypeSheet = false
                            }

                        // Centered, narrow popup
                        VStack(spacing: 20) {
                            Text("Add Note")
                                .font(.system(.title3, design: .serif).weight(.semibold))

                            HStack(spacing: 16) {
                                NoteTypeIconButton(
                                    systemName: "text.alignleft",
                                    label: "Text"
                                ) {
                                    showingNewNoteTypeSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        editingNote = nil
                                        showingTextSheet = true
                                    }
                                }

                                NoteTypeIconButton(
                                    systemName: "photo",
                                    label: "Image"
                                ) {
                                    showingNewNoteTypeSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        editingNote = nil
                                        showingImageSheet = true
                                    }
                                }
                            }

                            HStack(spacing: 16) {
                                NoteTypeIconButton(
                                    systemName: "chevron.left.forwardslash.chevron.right",
                                    label: "Code"
                                ) {
                                    showingNewNoteTypeSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        editingNote = nil
                                        showingCodeSheet = true
                                    }
                                }

                                NoteTypeIconButton(
                                    systemName: "function",
                                    label: "Math"
                                ) {
                                    showingNewNoteTypeSheet = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        editingNote = nil
                                        showingMathSheet = true
                                    }
                                }
                            }

                            HStack(spacing: 16) {
                                Button("Cancel") {
                                    showingNewNoteTypeSheet = false
                                }
                                .font(.system(.body, design: .serif))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)

                                Button("Add") {
                                    showingNewNoteTypeSheet = false
                                }
                                .font(.system(.body, design: .serif))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(16)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: 280)
                        .background(Color(.systemBackground))
                        .cornerRadius(24)
                        .shadow(radius: 20)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut, value: showingNewNoteTypeSheet)
                }
            }
            .toolbar {
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
                            .accessibilityLabel("Filter and Sort")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        editingNote = nil
                        showingNewNoteTypeSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.orange)
                            .cornerRadius(8)
                            .accessibilityLabel("Add Note")
                    }
                }
            }
            .overlay {
                // Add Note popup (already there)
                if showingNewNoteTypeSheet {
                    /* your Add Note popup code */
                }

                // Editor popups
                if showingTextSheet {
                    CenteredPopupCard {
                        NewTextNoteSheet(
                            editingNote: editingNote,
                            onSave: { note in
                                if let existing = editingNote {
                                    var updated = existing
                                    updated.title = note.title
                                    updated.blocks = note.blocks
                                    store.updateNote(updated)
                                } else {
                                    store.notes.insert(note, at: 0)
                                    store.updateNote(note)
                                }
                                editingNote = nil
                                showingTextSheet = false
                            }
                        )
                    } onBackgroundTap: {
                        showingTextSheet = false
                    }
                } else if showingImageSheet {
                    CenteredPopupCard {
                        NewImageNoteSheet(
                            editingNote: editingNote,
                            onSave: { note in
                                if let existing = editingNote {
                                    var updated = existing
                                    updated.title = note.title
                                    updated.blocks = note.blocks
                                    store.updateNote(updated)
                                } else {
                                    store.notes.insert(note, at: 0)
                                    store.updateNote(note)
                                }
                                editingNote = nil
                                showingImageSheet = false
                            }
                        )
                    } onBackgroundTap: {
                        showingImageSheet = false
                    }
                } else if showingCodeSheet {
                    CenteredPopupCard {
                        NewCodeNoteSheet(
                            editingNote: editingNote,
                            onSave: { note in
                                if let existing = editingNote {
                                    var updated = existing
                                    updated.title = note.title
                                    updated.blocks = note.blocks
                                    store.updateNote(updated)
                                } else {
                                    store.notes.insert(note, at: 0)
                                    store.updateNote(note)
                                }
                                editingNote = nil
                                showingCodeSheet = false
                            }
                        )
                    } onBackgroundTap: {
                        showingCodeSheet = false
                    }
                } else if showingMathSheet {
                    CenteredPopupCard {
                        NewMathNoteSheet(
                            editingNote: editingNote,
                            onSave: { note in
                                if let existing = editingNote {
                                    var updated = existing
                                    updated.title = note.title
                                    updated.blocks = note.blocks
                                    store.updateNote(updated)
                                } else {
                                    store.notes.insert(note, at: 0)
                                    store.updateNote(note)
                                }
                                editingNote = nil
                                showingMathSheet = false
                            }
                        )
                    } onBackgroundTap: {
                        showingMathSheet = false
                    }
                }
            }
            .alert("Save Error", isPresented: .constant(store.saveError != nil)) {
                Button("OK") {
                    store.saveError = nil
                }
            } message: {
                if let error = store.saveError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Note card

    struct NoteCardView: View {
        let note: Note
        @Binding var previewCache: [UUID: String]

        private var firstTextLikeBlock: NoteBlock? {
            note.blocks.first(where: { $0.type == .text || $0.type == .heading || $0.type == .code })
        }

        private var firstMathBlock: NoteBlock? {
            note.blocks.first(where: { $0.type == .calculation })
        }

        private var displayTitle: String {
            let trimmedTitle = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTitle.isEmpty {
                return trimmedTitle
            }

            if let textBlock = firstTextLikeBlock {
                let plain = getCachedStrippedHTML(for: textBlock)
                if !plain.isEmpty { return plain }
            }

            if let mathBlock = firstMathBlock {
                return mathBlock.content
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
                // Fixed size image or text preview container
                GeometryReader { geometry in
                    ZStack {
                        if let firstImageBlock = note.blocks.first(where: { $0.type == .image }),
                           let data = firstImageBlock.imageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geometry.size.width, height: 150)
                                .clipped()
                                .accessibilityLabel("Note image")
                        } else if let codeBlock = note.blocks.first(where: { $0.type == .code }) {
                            // Code preview with dark theme, centered text
                            let bg = Color(hex: "1E1E1E")

                            bg
                                .frame(width: geometry.size.width, height: 150)

                            Text(codeBlock.content.isEmpty ? "// Empty code block" : codeBlock.content)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Color(hex: "D4D4D4"))
                                .multilineTextAlignment(.center)
                                .lineLimit(8)
                                .truncationMode(.tail)
                                .padding(12)
                                .frame(width: geometry.size.width, height: 150, alignment: .center)
                        } else if let mathBlock = note.blocks.first(where: { $0.type == .calculation }) {
                            // Math preview showing equation and result, centered and adaptive
                            Color.white
                                .frame(width: geometry.size.width, height: 150)

                            VStack(spacing: 8) {
                                Text(mathBlock.content.isEmpty ? "..." : mathBlock.content)
                                    .font(.system(size: 16, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)

                                HStack(spacing: 6) {
                                    Text("=")
                                        .font(.system(size: 18, design: .serif))
                                        .foregroundColor(.secondary)

                                    Text(calculateResult(mathBlock.content))
                                        .font(.system(size: 34, design: .serif).bold())
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.4)
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(width: geometry.size.width, height: 150, alignment: .center)
                        } else {
                            Color.white
                                .frame(width: geometry.size.width, height: 150)

                            Text(getPreviewText())
                                .font(firstTextLikeBlock.map(previewFont(for:)) ?? .system(size: 20, design: .serif))
                                .minimumScaleFactor(0.6)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .truncationMode(.tail)
                                .foregroundColor(.primary)
                                .padding(12)
                                .frame(width: geometry.size.width, height: 150)
                        }
                    }
                }
                .frame(height: 150)
                .clipped()

                // Bottom info section
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
                                .accessibilityHidden(true)
                        }
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
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Tags: \(tags.prefix(3).joined(separator: ", "))")
                    }
                }
                .padding(10)
            }
            .frame(maxWidth: .infinity)
            .background(
                note.blocks.contains { $0.type == .code }
                    ? Color(hex: "1E1E1E")
                    : Color.white
            )
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        }

        private func getPreviewText() -> String {
            if let block = firstTextLikeBlock {
                return getCachedStrippedHTML(for: block)
            }
            return "New Note"
        }

        private func getCachedStrippedHTML(for block: NoteBlock) -> String {
            if let cached = previewCache[block.id] {
                return cached
            }
            let stripped = stripHTML(from: block.content)
            previewCache[block.id] = stripped
            return stripped
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

        private func calculateResult(_ equation: String) -> String {
            let cleanEq = equation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanEq.isEmpty else { return "..." }

            let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
            if cleanEq.rangeOfCharacter(from: allowed.inverted) != nil {
                return "?"
            }

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
                guard let decimalString = formatter.string(from: NSNumber(value: number)) else {
                    return "?"
                }
                if decimalString.count > 15 {
                    return String(decimalString.prefix(15))
                }
                return decimalString
            } else {
                return "?"
            }
        }
    }
}

// Icon button used in the Add Note popup
struct NoteTypeIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemName)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(.caption, design: .serif))
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(18)
        }
    }
}
struct CenteredPopupCard<Content: View>: View {
    let content: Content
    let onBackgroundTap: () -> Void

    init(@ViewBuilder content: () -> Content,
         onBackgroundTap: @escaping () -> Void) {
        self.content = content()
        self.onBackgroundTap = onBackgroundTap
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    onBackgroundTap()
                }

            VStack {
                content
            }
            .padding(20)
            .frame(maxWidth: 360, maxHeight: 480) // similar size to Add Note popup
            .background(Color(.systemBackground))
            .cornerRadius(24)
            .shadow(radius: 20)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: true)
    }
}
