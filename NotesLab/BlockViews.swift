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
                            .accessibilityLabel("Tag \(tag), tap to remove")
                    }

                    Button {
                        showTagInput.toggle()
                    } label: {
                        Image(systemName: "number")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Add tag")
                }
            }
        }
        .padding(.top, 4)
        .popover(isPresented: $showTagInput) {
            HStack {
                TextField("New tag", text: $newTag)
                    .onSubmit(addTag)
                    .textInputAutocapitalization(.never)
                Button("Add", action: addTag)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .presentationCompactAdaptation(.popover)
        }
    }

    private func addTag() {
        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, tag.count <= 50 else { return }
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
                .accessibilityLabel("Heading")

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
                .font(.system(size: 14, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(hex: "1E1E1E"))
                .foregroundColor(Color(hex: "D4D4D4"))
                .cornerRadius(8)
                .frame(minHeight: 80)
                .accessibilityLabel("Code editor")

            BlockFooterView(hashtags: $hashtags, createdAt: createdAt)
        }
    }
}

// MARK: - Calculation Block

struct CalculationBlockView: View {
    @Binding var equation: String
    @Binding var hashtags: [String]
    var createdAt: Date

    var result: String {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("e.g. 5.5 + 10.2", text: $equation)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .monospaced))
                    .accessibilityLabel("Equation input")

                Text("=")
                    .foregroundColor(.secondary)

                Text(result)
                    .font(.system(size: 28, design: .serif).weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .foregroundColor(.blue)

                Spacer()
            }
            .padding(.bottom, 8)

            BlockFooterView(hashtags: $hashtags, createdAt: createdAt)
        }
    }
}
