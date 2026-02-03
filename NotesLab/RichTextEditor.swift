import SwiftUI
import UIKit

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    
    func makeUIView(context: Context) -> RichTextView {
        let textView = RichTextView()
        textView.isEditable = true
        textView.isScrollEnabled = false // Allows auto-height expansion
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        
        // Ensure text wraps
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        
        context.coordinator.textView = textView
        
        // Ensure initial load happens on main thread if not already
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
        // FIX: Ensure the view updates when the binding changes externally (e.g. drag reorder).
        // We check if the view is NOT the first responder (typing) to avoid loop/cursor issues.
        if !uiView.isFirstResponder {
            // FIX: Dispatch to main thread to avoid NSAttributedString crashes
            if Thread.isMainThread {
                context.coordinator.setHTML(text, in: uiView)
            } else {
                DispatchQueue.main.async {
                    context.coordinator.setHTML(text, in: uiView)
                }
            }
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
            // Convert attributed string back to HTML
            // This reads from UI so it must be on main thread (delegate methods usually are)
            if let htmlData = try? textView.attributedText.data(from: NSRange(location: 0, length: textView.attributedText.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                if let htmlString = String(data: htmlData, encoding: .utf8) {
                    parent.text = htmlString
                }
            }
        }
        
        func setHTML(_ html: String, in textView: UITextView) {
            // If empty, just clear and return
            if html.isEmpty {
                textView.text = ""
                return
            }
            
            // Safely get data
            guard let data = html.data(using: .utf8) else {
                textView.text = html // Fallback to raw text if encoding fails
                return
            }
            
            // FIX: Wrap in do-catch block for safety against the specific crash
            do {
                let attributedString = try NSAttributedString(
                    data: data,
                    options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
                    documentAttributes: nil
                )
                
                let mutable = NSMutableAttributedString(attributedString: attributedString)
                
                // Fix font size and ENSURE WRAPPING
                mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                    if value == nil {
                        mutable.addAttribute(.font, value: UIFont.preferredFont(forTextStyle: .body), range: range)
                    }
                }
                
                // Explicitly remove any paragraph style that might prevent wrapping (like fixed width)
                // and ensure the font color adapts to light/dark mode
                mutable.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: mutable.length))
                
                textView.attributedText = mutable
            } catch {
                print("Error parsing HTML for editor: \(error)")
                textView.text = html // Fallback
            }
        }
    }
}

// Custom TextView to handle actions
class RichTextView: UITextView {
    
    @objc func toggleBold() { toggleTrait(.traitBold) }
    @objc func toggleItalic() { toggleTrait(.traitItalic) }
    @objc func setSerif() { updateFontDesign(.serif) }
    @objc func setMono() { updateFontDesign(.monospaced) }
    @objc func setStandard() { updateFontDesign(.default) }
    
    private func currentFont() -> UIFont? {
        if self.selectedRange.length > 0 {
            return self.attributedText.attribute(.font, at: self.selectedRange.location, effectiveRange: nil) as? UIFont
        } else {
            return self.typingAttributes[.font] as? UIFont ?? self.font
        }
    }
    
    private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let currentFont = currentFont() else { return }
        var traits = currentFont.fontDescriptor.symbolicTraits
        if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
        
        if let newDescriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
            let newFont = UIFont(descriptor: newDescriptor, size: currentFont.pointSize)
            applyAttribute(.font, value: newFont)
        }
    }
    
    private func updateFontDesign(_ design: UIFontDescriptor.SystemDesign) {
        guard let currentFont = currentFont() else { return }
        let currentTraits = currentFont.fontDescriptor.symbolicTraits
        if let baseDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).withDesign(design),
           let finalDescriptor = baseDescriptor.withSymbolicTraits(currentTraits) {
            let newFont = UIFont(descriptor: finalDescriptor, size: currentFont.pointSize)
            applyAttribute(.font, value: newFont)
        }
    }
    
    private func applyAttribute(_ key: NSAttributedString.Key, value: Any) {
        let range = self.selectedRange
        self.textStorage.addAttributes([key: value], range: range)
        self.typingAttributes[key] = value
        delegate?.textViewDidChange?(self)
    }
    
    // Ensure layout updates correctly for auto-sizing
    override var intrinsicContentSize: CGSize {
        // Calculate intrinsic size based on content
        let size = sizeThatFits(CGSize(width: frame.width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: size.height)
    }
}
