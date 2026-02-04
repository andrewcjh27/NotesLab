import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String   // HTML string

    func makeUIView(context: Context) -> RichTextView {
        let textView = RichTextView()
        textView.isEditable = true
        textView.isScrollEnabled = false        // Let SwiftUI drive height
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator

        // Ensure wrapping
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        textView.font = UIFont.preferredFont(forTextStyle: .body)

        context.coordinator.textView = textView

        // Initial HTML load
        if Thread.isMainThread {
            context.coordinator.setHTML(text, in: textView)
        } else {
            DispatchQueue.main.async {
                context.coordinator.setHTML(text, in: textView)
            }
        }

        return textView
    }

    func updateUIView(_ uiView: RichTextView, context: Context) {
        // Only push binding → UI when user is NOT typing
        guard !uiView.isFirstResponder else { return }

        let apply = {
            context.coordinator.setHTML(text, in: uiView)
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        weak var textView: UITextView?

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            // Convert attributed text → HTML for storage
            let range = NSRange(location: 0, length: textView.attributedText.length)
            if let data = try? textView.attributedText.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            ),
               let html = String(data: data, encoding: .utf8) {
                parent.text = html
            }
        }

        func setHTML(_ html: String, in textView: UITextView) {
            // Empty input
            guard !html.isEmpty else {
                textView.attributedText = nil
                return
            }

            guard let data = html.data(using: .utf8) else {
                textView.text = html        // Fallback to plain text
                return
            }

            do {
                let attributed = try NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                )

                let mutable = NSMutableAttributedString(attributedString: attributed)

                // Normalize fonts and colors so they work with dynamic type + dark mode
                let fullRange = NSRange(location: 0, length: mutable.length)

                mutable.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                    if value == nil {
                        mutable.addAttribute(
                            .font,
                            value: UIFont.preferredFont(forTextStyle: .body),
                            range: range
                        )
                    }
                }

                mutable.addAttribute(
                    .foregroundColor,
                    value: UIColor.label,
                    range: fullRange
                )

                textView.attributedText = mutable
            } catch {
                print("Error parsing HTML for editor: \(error)")
                textView.text = html        // Fallback if HTML is malformed
            }
        }
    }
}

// Custom UITextView with basic rich‑text toggles
class RichTextView: UITextView {

    @objc func toggleBold() { toggleTrait(.traitBold) }
    @objc func toggleItalic() { toggleTrait(.traitItalic) }

    @objc func setSerif() { updateFontDesign(.serif) }
    @objc func setMono() { updateFontDesign(.monospaced) }
    @objc func setStandard() { updateFontDesign(.default) }

    private func currentFont() -> UIFont? {
        if selectedRange.length > 0 {
            return attributedText.attribute(
                .font,
                at: selectedRange.location,
                effectiveRange: nil
            ) as? UIFont
        } else {
            return typingAttributes[.font] as? UIFont ?? font
        }
    }

    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let current = currentFont() else { return }

        var traits = current.fontDescriptor.symbolicTraits
        if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }

        if let descriptor = current.fontDescriptor.withSymbolicTraits(traits) {
            let newFont = UIFont(descriptor: descriptor, size: current.pointSize)
            applyAttribute(.font, value: newFont)
        }
    }

    private func updateFontDesign(_ design: UIFontDescriptor.SystemDesign) {
        guard let current = currentFont() else { return }

        let traits = current.fontDescriptor.symbolicTraits
        if let base = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: .body)
            .withDesign(design),
           let final = base.withSymbolicTraits(traits) {
            let newFont = UIFont(descriptor: final, size: current.pointSize)
            applyAttribute(.font, value: newFont)
        }
    }

    private func applyAttribute(_ key: NSAttributedString.Key, value: Any) {
        let range = selectedRange
        guard range.length > 0 || key == .font else { return }

        textStorage.addAttributes([key: value], range: range)
        typingAttributes[key] = value
        delegate?.textViewDidChange?(self)
    }

    // Let SwiftUI compute height based on content
    override var intrinsicContentSize: CGSize {
        let size = sizeThatFits(
            CGSize(width: bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width,
                   height: .greatestFiniteMagnitude)
        )
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }
}
