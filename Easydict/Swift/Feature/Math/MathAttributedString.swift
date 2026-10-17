//
//  MathAttributedString.swift
//  Easydict
//

import AppKit

/// Replaces protected formula tokens with vector attachments and preserves their TeX for copy.
enum MathAttributedString {
    static let sourceKey = NSAttributedString.Key("EasydictMathSource")

    static func render(
        _ document: MathExpressionParser.Document,
        results: [String: MathJaxRenderer.Result],
        markdown: MarkdownRenderer?,
        attributes: [NSAttributedString.Key: Any],
        maxWidth: CGFloat
    ) -> NSAttributedString {
        let output = NSMutableAttributedString(attributedString: markdown?.render(document.text)
            ?? NSAttributedString(string: document.text, attributes: attributes))
        for (token, expression) in document.formulas {
            let range = (output.string as NSString).range(of: token)
            guard range.location != NSNotFound else { continue }
            let tokenAttributes = output.attributes(at: range.location, effectiveRange: nil)
            let font = tokenAttributes[.font] as? NSFont ?? .systemFont(ofSize: 14)
            let color = tokenAttributes[.foregroundColor] as? NSColor ?? .labelColor
            guard let result = results[expression.cacheKey],
                  let attachment = attachment(result, source: expression.source, font: font, color: color, maxWidth: maxWidth)
            else {
                output.replaceCharacters(in: range, with: NSAttributedString(string: expression.source, attributes: tokenAttributes))
                continue
            }
            let replacement = NSMutableAttributedString(attachment: attachment)
            replacement.addAttributes(tokenAttributes, range: NSRange(location: 0, length: replacement.length))
            replacement.addAttribute(sourceKey, value: expression.source, range: NSRange(location: 0, length: replacement.length))
            if expression.display {
                let style = (tokenAttributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                    ?? NSMutableParagraphStyle()
                style.alignment = .center
                style.paragraphSpacingBefore = 6
                style.paragraphSpacing = 6
                replacement.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: replacement.length))
            }
            output.replaceCharacters(in: range, with: replacement)
        }
        return output
    }

    static func sourceText(_ attributed: NSAttributedString, in range: NSRange) -> String {
        let selection = attributed.attributedSubstring(from: range)
        var result = ""
        selection.enumerateAttribute(sourceKey, in: NSRange(location: 0, length: selection.length)) { value, run, _ in
            result += value as? String ?? (selection.string as NSString).substring(with: run)
        }
        return result
    }

    private static func attachment(
        _ result: MathJaxRenderer.Result, source: String, font: NSFont, color: NSColor, maxWidth: CGFloat
    ) -> NSTextAttachment? {
        guard let svg = result.svg, let rgb = color.usingColorSpace(.sRGB),
              result.width.isFinite, result.height.isFinite, result.depth.isFinite,
              result.width > 0, result.height > 0
        else { return nil }
        let colorString = String(
            format: "#%02x%02x%02x", Int(rgb.redComponent * 255),
            Int(rgb.greenComponent * 255), Int(rgb.blueComponent * 255)
        )
        let colored = svg.replacingOccurrences(of: "currentColor", with: colorString)
            .replacingOccurrences(of: "<svg ", with: "<svg opacity=\"\(rgb.alphaComponent)\" ")
        guard let image = NSImage(data: Data(colored.utf8)) else { return nil }
        let scale = min(font.pointSize, max(1, maxWidth) / result.width)
        image.size = NSSize(width: result.width * scale, height: result.height * scale)
        image.accessibilityDescription = source
        let attachment = NSTextAttachment()
        let cell = MathAttachmentCell(imageCell: image)
        cell.baseline = -result.depth * scale
        attachment.attachmentCell = cell
        return attachment
    }
}

private final class MathAttachmentCell: NSTextAttachmentCell {
    var baseline: CGFloat = 0

    override func cellBaselineOffset() -> NSPoint {
        NSPoint(x: 0, y: baseline)
    }
}
