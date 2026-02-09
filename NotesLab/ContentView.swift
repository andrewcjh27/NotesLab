import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

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
        case custom = "Custom Order"
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

    // Drag-and-drop reordering
    @State private var draggedNote: Note? = nil

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

        switch sortOption {
        case .recent:
            return filtered.sorted { $0.date > $1.date }
        case .alphabetical:
            return filtered.sorted { $0.title < $1.title }
        case .custom:
            // Preserve the natural order from store.notes (filter already maintains it)
            return filtered
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

                    LazyVGrid(columns: columns, alignment: .top, spacing: 16) {
                        ForEach(filteredNotes) { note in
                            NavigationLink(value: note) {
                                NoteCardView(note: note, previewCache: $previewCache)
                            }
                            .buttonStyle(.plain)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 12))
                            .opacity(draggedNote?.id == note.id ? 0.4 : 1.0)
                            .onDrag {
                                draggedNote = note
                                sortOption = .custom
                                return NSItemProvider(object: note.id.uuidString as NSString)
                            }
                            .onDrop(of: [UTType.text], delegate: NoteCardDropDelegate(
                                targetNote: note,
                                draggedNote: $draggedNote,
                                store: store
                            ))
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
                    .onDrop(of: [UTType.text], delegate: GridBackgroundDropDelegate(draggedNote: $draggedNote))
                    .onChange(of: store.notes) { _ in
                        // Failsafe: clear drag state whenever the notes array settles
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            if draggedNote != nil {
                                withAnimation { draggedNote = nil }
                            }
                        }
                    }
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
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                showingNewNoteTypeSheet = false
                            }

                        // Compact, rounded popup
                        VStack(spacing: 14) {
                            Text("New Note")
                                .font(.system(.headline, design: .serif))

                            // 2x2 grid of type buttons
                            HStack(spacing: 12) {
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

                            HStack(spacing: 12) {
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

                            Button {
                                showingNewNoteTypeSheet = false
                            } label: {
                                Text("Cancel")
                                    .font(.system(.subheadline, design: .serif))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 18)
                        .padding(.bottom, 8)
                        .frame(maxWidth: 240)
                        .background(Color(.systemBackground))
                        .cornerRadius(28)
                        .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: showingNewNoteTypeSheet)
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
                            },
                            onCancel: {
                                editingNote = nil
                                showingTextSheet = false
                            }
                        )
                    } onBackgroundTap: {
                        editingNote = nil
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
                            },
                            onCancel: {
                                editingNote = nil
                                showingImageSheet = false
                            }
                        )
                    } onBackgroundTap: {
                        editingNote = nil
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
                            },
                            onCancel: {
                                editingNote = nil
                                showingCodeSheet = false
                            }
                        )
                    } onBackgroundTap: {
                        editingNote = nil
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
                            },
                            onCancel: {
                                editingNote = nil
                                showingMathSheet = false
                            }
                        )
                    } onBackgroundTap: {
                        editingNote = nil
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

        /// Check if image is predominantly light by sampling average brightness
        private var imageIsLight: Bool {
            guard let firstImageBlock = note.blocks.first(where: { $0.type == .image }),
                  let data = firstImageBlock.imageData,
                  let uiImage = UIImage(data: data) else { return true }
            return Self.isImageLight(uiImage)
        }

        /// True if the note has an image block with valid image data
        private var hasImage: Bool {
            guard let firstImageBlock = note.blocks.first(where: { $0.type == .image }),
                  let data = firstImageBlock.imageData,
                  let _ = UIImage(data: data) else { return false }
            return true
        }

        private var adaptivePrimaryColor: Color {
            imageIsLight ? .black : .white
        }

        private var adaptiveSecondaryColor: Color {
            imageIsLight ? Color.black.opacity(0.6) : Color.white.opacity(0.7)
        }

        private var adaptiveTagBackground: Color {
            imageIsLight ? Color.indigo.opacity(0.15) : Color.white.opacity(0.2)
        }

        private var adaptiveTagForeground: Color {
            imageIsLight ? .indigo : .white
        }

        /// Card background color from the note's stored hex, falling back to white
        private var cardBackground: Color {
            if let hex = note.cardColorHex {
                return Color(hex: hex)
            }
            return Color.white
        }

        private var gradientColors: [Color] {
            imageIsLight
                ? [Color.white.opacity(0), Color.white.opacity(0.85)]
                : [Color.black.opacity(0), Color.black.opacity(0.7)]
        }

        var body: some View {
            if hasImage {
                // Full-bleed image card
                imageCardBody
            } else {
                // Standard card (code / math / text)
                standardCardBody
            }
        }

        // MARK: - Image card (full-bleed)

        private var imageCardBody: some View {
            let firstImageBlock = note.blocks.first(where: { $0.type == .image })!
            let uiImage = UIImage(data: firstImageBlock.imageData!)!

            return GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    // Full-bleed image
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityLabel("Note image")

                    // Gradient overlay for text readability
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.55)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                    // Overlaid info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(adaptivePrimaryColor)
                            .lineLimit(1)

                        HStack {
                            Text(note.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundColor(adaptiveSecondaryColor)
                            Spacer()
                            if !note.blocks.isEmpty {
                                Image(systemName: "photo")
                                    .font(.caption2)
                                    .foregroundColor(adaptiveSecondaryColor)
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
                                            .background(adaptiveTagBackground)
                                            .foregroundColor(adaptiveTagForeground)
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
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.08), radius: 5, x: 0, y: 2)
        }

        // MARK: - Standard card (code, math, text)

        private var standardCardBody: some View {
            VStack(alignment: .leading, spacing: 0) {
                // Content preview — height adapts to content
                Group {
                    if let codeBlock = note.blocks.first(where: { $0.type == .code }) {
                        Text(codeBlock.content.isEmpty ? "// Empty code block" : codeBlock.content)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(hex: "D4D4D4"))
                            .multilineTextAlignment(.leading)
                            .lineLimit(12)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    } else if let mathBlock = note.blocks.first(where: { $0.type == .calculation }) {
                        VStack(spacing: 8) {
                            Text(mathBlock.content.isEmpty ? "..." : mathBlock.content)
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundColor(.primary)
                                .lineLimit(2)
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
                        .frame(maxWidth: .infinity)
                        .padding(12)
                    } else {
                        Text(getPreviewText())
                            .font(firstTextLikeBlock.map(previewFont(for:)) ?? .system(size: 20, design: .serif))
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.leading)
                            .lineLimit(8)
                            .truncationMode(.tail)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
                .frame(minHeight: 80)

                Spacer(minLength: 0)

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
                    : cardBackground
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

        /// Sample the bottom third of the image to determine if it's light or dark
        static func isImageLight(_ image: UIImage) -> Bool {
            guard let cgImage = image.cgImage else { return true }

            let width = cgImage.width
            let height = cgImage.height

            // Sample the bottom third (where the text overlay sits)
            let sampleHeight = max(height / 3, 1)
            let sampleY = height - sampleHeight

            guard let cropped = cgImage.cropping(to: CGRect(x: 0, y: sampleY, width: width, height: sampleHeight)) else {
                return true
            }

            // Down-sample to a tiny size for fast average
            let sampleSize = 4
            let bytesPerPixel = 4
            let bytesPerRow = sampleSize * bytesPerPixel
            var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * bytesPerPixel)

            guard let context = CGContext(
                data: &pixelData,
                width: sampleSize,
                height: sampleSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return true }

            context.draw(cropped, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

            var totalLuminance: Double = 0
            let pixelCount = sampleSize * sampleSize
            for i in 0..<pixelCount {
                let offset = i * bytesPerPixel
                let r = Double(pixelData[offset]) / 255.0
                let g = Double(pixelData[offset + 1]) / 255.0
                let b = Double(pixelData[offset + 2]) / 255.0
                // Relative luminance (perceived brightness)
                totalLuminance += 0.299 * r + 0.587 * g + 0.114 * b
            }

            let avgLuminance = totalLuminance / Double(pixelCount)
            return avgLuminance > 0.55
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
            VStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(.caption2, design: .serif))
            }
            .foregroundColor(.primary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
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
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onBackgroundTap()
                }

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: 340)
            .background(Color(.systemBackground))
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 8)
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}

// MARK: - Drop Delegates for grid card reordering

struct NoteCardDropDelegate: DropDelegate {
    let targetNote: Note
    @Binding var draggedNote: Note?
    let store: NotesStore

    func performDrop(info: DropInfo) -> Bool {
        withAnimation {
            draggedNote = nil
        }
        return true
    }

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedNote, dragged.id != targetNote.id else { return }

        withAnimation(.easeInOut(duration: 0.25)) {
            store.swapNotes(fromID: dragged.id, toID: targetNote.id)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        // No action needed on exit
    }
}

/// Catches drops that land outside any card to clear the drag state
struct GridBackgroundDropDelegate: DropDelegate {
    @Binding var draggedNote: Note?

    func performDrop(info: DropInfo) -> Bool {
        withAnimation {
            draggedNote = nil
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
