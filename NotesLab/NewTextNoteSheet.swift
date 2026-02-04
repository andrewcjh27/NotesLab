//
//  NewTextNoteSheet.swift
//  NotesLab
//
//  Created by Andrew Choi on 2/4/26.
//

import SwiftUI

struct NewTextNoteSheet: View {
    @Binding var text: String
    @Binding var hashtags: [String]
    @Binding var description: String

    var onAdd: (_ text: String,
                _ tags: [String],
                _ description: String,
                _ isBold: Bool,
                _ isItalic: Bool,
                _ useSerif: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 1
    @State private var newTag = ""

    @State private var isBold = false
    @State private var isItalic = false
    @State private var useSerif = false

    var body: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                if step == 1 {
                    textStep
                } else {
                    metaStep
                }

                Spacer(minLength: 0)

                controlsRow
            }
            .padding()
            .frame(maxWidth: 360, maxHeight: 420)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
        }
        .presentationBackground(.clear)
    }

    private var textStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New text")
                .font(.headline)

            HStack(spacing: 16) {
                Button {
                    isBold.toggle()
                } label: {
                    Text("B")
                        .fontWeight(.bold)
                        .foregroundColor(isBold ? .primary : .secondary)
                }

                Button {
                    isItalic.toggle()
                } label: {
                    Text("I")
                        .italic()
                        .foregroundColor(isItalic ? .primary : .secondary)
                }

                Menu {
                    Button("Standard") { useSerif = false }
                    Button("Serif") { useSerif = true }
                } label: {
                    Text("Aa")
                        .foregroundColor(.primary)
                }
            }

            TextEditor(text: $text)
                .font(currentFont)
                .frame(minHeight: 180)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
        .padding(.horizontal, 4)
    }

    private var metaStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tags & details")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
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

                HStack {
                    TextField("Add hashtag", text: $newTag)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addTag)

                    Button { addTag() } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            TextField("Optional description", text: $description)
                .textFieldStyle(.roundedBorder)
        }
        .padding(.horizontal, 4)
    }

    private var controlsRow: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .foregroundColor(.secondary)

            Spacer()

            if step == 1 {
                Button {
                    step = 2
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                Button {
                    onAdd(text, hashtags, description, isBold, isItalic, useSerif)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add block")
                    }
                    .font(.headline)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var currentFont: Font {
        var base: Font = useSerif
            ? .system(size: 18, design: .serif)
            : .system(size: 18, design: .default)

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
        guard !trimmed.isEmpty else { return }
        hashtags.append(trimmed)
        newTag = ""
    }
}
