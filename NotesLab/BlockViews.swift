//
//  BlockViews.swift
//  NotesLab
//
//  Created by Andrew Choi on 1/27/26.
//

import SwiftUI
import UIKit

// --- 1. Text Block View (UPDATED FOR RICH TEXT) ---
struct TextBlockView: View {
    @Binding var text: String
    
    var body: some View {
        // We use our new RichTextEditor here instead of a plain TextField.
        // It handles its own formatting internally via the keyboard toolbar.
        RichTextEditor(text: $text)
            .frame(minHeight: 40) // Allows it to grow
            .padding(.vertical, 4)
    }
}

// --- 2. Heading Block View ---
struct HeadingBlockView: View {
    @Binding var text: String
    
    var body: some View {
        if #available(iOS 16.0, *) {
            TextField("Heading", text: $text, axis: .vertical)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .padding(.top, 16)
        } else {
            TextField("Heading", text: $text)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .padding(.top, 16)
        }
    }
}

// --- 3. Code Block View ---
struct CodeBlockView: View {
    @Binding var code: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("CODE")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.bottom, 2)
            
            if #available(iOS 16.0, *) {
                TextEditor(text: $code)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .frame(minHeight: 60)
            } else {
                TextEditor(text: $code)
                    .font(.system(.body, design: .monospaced))
                    .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .frame(minHeight: 60)
            }
        }
        .padding(.vertical, 8)
    }
}

// --- 4. Calculation Block View ---
struct CalculationBlockView: View {
    @Binding var equation: String
    
    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()
    
    var result: String {
        let cleanEq = equation.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanEq.isEmpty { return "..." }

        let allowedCharacters = CharacterSet(charactersIn: "0123456789.+-*/() ")
        if cleanEq.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return "?"
        }
        
        let unsafeEndings = ["+", "-", "*", "/", "("]
        if unsafeEndings.contains(where: { cleanEq.hasSuffix($0) }) {
            return "..."
        }
        
        var openCount = 0
        for char in cleanEq {
            if char == "(" { openCount += 1 }
            else if char == ")" {
                openCount -= 1
                if openCount < 0 { return "?" }
            }
        }
        if openCount != 0 { return "..." }

        let expression = NSExpression(format: cleanEq)
        if let value = expression.expressionValue(with: nil, context: nil) as? NSNumber {
            return numberFormatter.string(from: value) ?? "..."
        } else {
            return "..."
        }
    }
    
    var body: some View {
        HStack {
            TextField("e.g. 5 + 10", text: $equation)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 150)
                .keyboardType(.numbersAndPunctuation)
                .font(.system(.body, design: .monospaced))
            
            Text("=")
                .foregroundColor(.secondary)
            
            Text(result)
                .font(.headline.monospaced())
                .foregroundColor(.blue)
            
            Spacer()
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// --- 5. Image Block View ---
struct ImageBlockView: View {
    let imageData: Data?
    
    var body: some View {
        if let data = imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .cornerRadius(12)
                .shadow(radius: 4)
                .frame(maxHeight: 300)
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
                .overlay(Text("No Image").foregroundColor(.gray))
                .cornerRadius(12)
        }
    }
}

// --- CANVAS PREVIEW ---
struct BlockViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Note: We use HTML strings for preview now
            TextBlockView(text: .constant("<b>Bold</b> and <i>Italic</i> text"))
            HeadingBlockView(text: .constant("Experiment 1"))
            CalculationBlockView(equation: .constant("12 * 5"))
            CodeBlockView(code: .constant("print('Hello World')"))
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
