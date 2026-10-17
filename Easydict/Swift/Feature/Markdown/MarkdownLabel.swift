//
//  MarkdownLabel.swift
//  Easydict
//
//  Created by Lin on 2026/4/30.
//  Copyright © 2026 izual. All rights reserved.
//

import AppKit
import Combine
import Defaults

/// Native translation text with independent Markdown and offline math rendering.
/// Keeps the inherited plain-text and appearance behavior when both are disabled.
@objc(EDMarkdownLabel)
final class MarkdownLabel: EZLabel {
    // MARK: Internal

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        // Preserve NSTextView's inherited initializer chain, including
        // init(frame:textContainer:), which AppKit calls from init(frame:).
        if mathPreference == nil { observeMathPreference() }
        updateDisplayedText()
    }

    @objc var mathEnabled = true {
        didSet {
            if oldValue != mathEnabled { updateDisplayedText() }
        }
    }
    @objc var didUpdateRenderedText: (() -> Void)?
    var didChangeLayoutWidth: (() -> Void)?

    /// Toggles between Markdown rendering and plain-text rendering. Re-applies
    /// the current `text` immediately so the visible state stays consistent.
    @objc var markdownEnabled: Bool = true {
        didSet {
            guard oldValue != markdownEnabled else { return }
            updateDisplayedText()
        }
    }

    override func updateDisplayedText() {
        renderGeneration += 1
        let generation = renderGeneration
        let source = text ?? ""
        let renderMath = mathEnabled && Defaults[.enableMathRendering]
        guard markdownEnabled || renderMath else {
            super.updateDisplayedText()
            return
        }
        let renderer = MarkdownRenderer(
            baseFont: font ?? .systemFont(ofSize: 14),
            foregroundColor: resolvedForegroundColor,
            lineSpacing: lineSpacing,
            paragraphSpacing: paragraphSpacing
        )
        guard renderMath else {
            textStorage?.setAttributedString(renderer.render(source))
            return
        }
        let document = MathExpressionParser.parse(source)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.paragraphSpacing = paragraphSpacing
        let attributed = MathAttributedString.render(
            document, markdown: markdownEnabled ? renderer : nil,
            attributes: [
                .font: font ?? .systemFont(ofSize: 14),
                .foregroundColor: resolvedForegroundColor,
                .paragraphStyle: paragraph,
            ],
            maxWidth: max(1, frame.width - 2 * (textContainer?.lineFragmentPadding ?? 0))
        )
        textStorage?.setAttributedString(attributed)
        let pending = document.formulas.map(\.expression).filter { MathJaxRenderer.shared.cached($0) == nil }
        guard !pending.isEmpty else { return }
        MathJaxRenderer.shared.prepare(pending) { [weak self] in
            guard let self, renderGeneration == generation else { return }
            updateDisplayedText()
            didUpdateRenderedText?()
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        let changed = abs(frame.width - newSize.width) > 0.5
        super.setFrameSize(newSize)
        if changed {
            updateDisplayedText()
            DispatchQueue.main.async { [weak self] in self?.didChangeLayoutWidth?() }
        }
    }

    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        if type == .string, let textStorage {
            return pboard.setString(MathAttributedString.sourceText(textStorage, in: selectedRange()), forType: .string)
        }
        return super.writeSelection(to: pboard, type: type)
    }

    override func copy(_ sender: Any?) {
        guard let textStorage, selectedRange().length > 0 else {
            super.copy(sender)
            return
        }
        var containsMath = false
        textStorage.enumerateAttribute(MathAttributedString.sourceKey, in: selectedRange()) { value, _, stop in
            if value != nil { containsMath = true; stop.pointee = true }
        }
        guard containsMath else {
            super.copy(sender)
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(MathAttributedString.sourceText(textStorage, in: selectedRange()), forType: .string)
    }

    // MARK: Private

    private var renderGeneration = 0
    private var mathPreference: AnyCancellable?

    private func observeMathPreference() {
        mathPreference = Defaults.publisher(.enableMathRendering, options: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateDisplayedText()
                self?.didUpdateRenderedText?()
            }
    }

    private var resolvedForegroundColor: NSColor {
        if let textForegroundColor { return textForegroundColor }
        return isDarkMode ? .ez_resultTextDark() : .ez_resultTextLight()
    }
}
