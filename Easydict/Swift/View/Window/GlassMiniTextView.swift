//
//  GlassMiniTextView.swift
//  Easydict
//

import AppKit
import SwiftUI

/// Selectable text with an unobtrusive overlay scroller, independent of the system's legacy scrollbar setting.
struct GlassMiniTextView: NSViewRepresentable {
    let text: String
    let allowsMath: Bool
    let didMeasure: (String, CGFloat) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller = GlassMiniScroller()
        scrollView.verticalScroller?.controlSize = .mini
        scrollView.focusRingType = .none

        let textView = MarkdownLabel(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        textView.isEditable = false
        textView.isSelectable = true
        textView.markdownEnabled = false
        textView.drawsBackground = false
        textView.focusRingType = .none
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: 1, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textForegroundColor = .labelColor
        textView.font = .systemFont(ofSize: 16)
        textView.lineSpacing = 4
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? MarkdownLabel else { return }
        textView.mathEnabled = allowsMath
        textView.didUpdateRenderedText = { [weak textView] in
            guard let textView, let manager = textView.layoutManager,
                  let container = textView.textContainer else { return }
            manager.ensureLayout(for: container)
            didMeasure(textView.text ?? "", ceil(manager.usedRect(for: container).height))
        }
        textView.didChangeLayoutWidth = textView.didUpdateRenderedText
        guard textView.text != text else { return }
        textView.text = text
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}

/// Retains AppKit scrolling, thumb dragging and automatic fading while drawing only a thin thumb.
private final class GlassMiniScroller: NSScroller {
    override static var isCompatibleWithOverlayScrollers: Bool { true }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    override func drawKnob() {
        let knob = rect(for: .knob)
        let thinKnob = NSRect(x: knob.midX - 1.5, y: knob.minY, width: 3, height: knob.height)
        NSColor.labelColor.withAlphaComponent(0.3).setFill()
        NSBezierPath(roundedRect: thinKnob, xRadius: 1.5, yRadius: 1.5).fill()
    }
}
