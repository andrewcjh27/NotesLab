//
//  BlockViews.swift
//  NotesLab
//

import SwiftUI
import UIKit

// MARK: - Shared Footer (time + tags)

struct BlockFooterView: View {
    @Binding var hashtags: [String]
    let createdAt: Date

    @State private var newTag = ""
    @State private var showTagInput = false

    var body: some View {
        HStack(alignment: .center) {
            Text(createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(hashtags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                            .onTapGesture {
                                if let idx = hashtags.firstIndex(of: tag) {
                                    hashtags.remove(at: idx)
                                }
                            }
                    }

                    Button {
                        showTagInput.toggle()
                    } label: {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 4)
        .popover(isPresented: $showTagInput) {
            HStack {
                TextField("New tag", text: $newTag)
                    .onSubmit(addTag)

                Button("Add", action: addTag)
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        hashtags.append(tag)
        newTag = ""
        showTagInput = false
    }
}

// MARK: - Heading Block (editable)

struct HeadingBlockView: View {
    @Binding var text: String
    @Binding var hashtags: [String]
    var createdAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Heading", text: $text)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .padding(.vertical, 4)

            BlockFooterView(hashtags: $hashtags, createdAt: createdAt)
        }
    }
}

// MARK: - Code Block

struct CodeBlockView: View {
    @Binding var code: String
    @Binding var hashtags: [String]
    var createdAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CODE")
                .font(.caption.bold())
                .foregroundColor(.gray)

            TextEditor(text: $code)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                .foregroundColor(.white)
                .cornerRadius(8)
                .frame(minHeight: 80)

            BlockFooterView(hashtags: $hashtags, createdAt: createdAt)
        }
    }
}

// MARK: - Calculation Block

struct CalculationBlockView: View {
    @Binding var equation: String
    @Binding var hashtags: [String]
    var createdAt: Date

    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    var result: String {
        let cleanEq = equation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEq.isEmpty else { return "..." }

        // Allow digits, decimal, basic operators and parentheses
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/() ")
        if cleanEq.rangeOfCharacter(from: allowed.inverted) != nil {
            return "?"
        }

        // Reject obviously bad endings like "+", "-", "*", "/"
        if let last = cleanEq.last, "+-*/".contains(last) {
            return "..."
        }

        // Try to evaluate with NSExpression; if it fails, show "?"
        let expression = NSExpression(format: cleanEq)
        if let value = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            return numberFormatter.string(from: value) ?? "..."
        } else {
            return "?"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("e.g. 5 + 10", text: $equation)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .font(.system(.body, design: .monospaced))

                Text("=")
                    .foregroundColor(.secondary)

                Text(result)
                    .font(.headline.monospaced())
                    .foregroundColor(.blue)

                Spacer()
            }
            .padding(.bottom, 8)

            BlockFooterView(hashtags: $hashtags, createdAt: createdAt)
        }
    }
}

// MARK: - Image Block

struct ImageBlockView: View {
    let imageData: Data?
    @Binding var hashtags: [String]
    var createdAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let data = imageData,
               let uiImage = UIImage(data: data) {

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()                // fill the window
                    .frame(maxWidth: .infinity)    // use full block width
                    .frame(height: 220)            // constant block height
                    .clipped()                     // crop overflow [web:30][web:48]
                    .cornerRadius(8)

            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 220)
                    .overlay(
                        Text("No Image").foregroundColor(.gray)
                    )
                    .cornerRadius(8)
            }

            BlockFooterView(hashtags: $hashtags, createdAt: createdAt)
        }
    }
}
