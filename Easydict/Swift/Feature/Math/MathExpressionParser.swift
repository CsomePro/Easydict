//
//  MathExpressionParser.swift
//  Easydict
//

import Foundation

/// A delimited expression, retaining its source for fallback and copying.
struct MathExpression: Hashable {
    let source: String
    let tex: String
    let display: Bool

    var cacheKey: String { (display ? "display:" : "inline:") + tex }
}

/// Protects formulas before Markdown parsing, leaving code and incomplete delimiters literal.
enum MathExpressionParser {
    struct Document {
        let text: String
        let formulas: [(token: String, expression: MathExpression)]
    }

    static func parse(_ source: String) -> Document {
        let characters = Array(source)
        let prefix = "\u{E000}" + UUID().uuidString + ":"
        var output = ""
        var formulas: [(String, MathExpression)] = []
        var index = 0
        var fence: (character: Character, count: Int)?
        var lineStart = true

        func matches(_ delimiter: [Character], at position: Int) -> Bool {
            position + delimiter.count <= characters.count
                && Array(characters[position ..< position + delimiter.count]) == delimiter
        }

        func runLength(at position: Int) -> Int {
            var end = position
            while end < characters.count, characters[end] == characters[position] { end += 1 }
            return end - position
        }

        while index < characters.count {
            if formulas.count >= 64 {
                output += String(characters[index...])
                break
            }
            let char = characters[index]
            if lineStart, char == " " || char == "\t" {
                output.append(char)
                index += 1
                continue
            }
            if lineStart, char == "`" || char == "~" {
                let count = runLength(at: index)
                if count >= 3 {
                    if let open = fence {
                        if open.character == char, count >= open.count { fence = nil }
                    } else {
                        fence = (char, count)
                    }
                    output += String(repeating: String(char), count: count)
                    index += count
                    lineStart = false
                    continue
                }
            }
            lineStart = char == "\n"
            if fence != nil {
                output.append(char)
                index += 1
                continue
            }
            if char == "`" {
                let count = runLength(at: index)
                var end = index + count
                while end < characters.count {
                    if characters[end] == "`" {
                        let closingCount = runLength(at: end)
                        if closingCount == count {
                            end += count
                            break
                        }
                        end += closingCount
                    } else {
                        end += 1
                    }
                }
                output += String(characters[index ..< end])
                index = end
                continue
            }

            let open: [Character]
            let close: [Character]
            let display: Bool
            if matches(Array("\\["), at: index) {
                open = Array("\\["); close = Array("\\]"); display = true
            } else if matches(Array("\\("), at: index) {
                open = Array("\\("); close = Array("\\)"); display = false
            } else if matches(Array("$$"), at: index) {
                open = Array("$$"); close = open; display = true
            } else if char == "$", index + 1 < characters.count,
                      !characters[index + 1].isWhitespace {
                open = ["$"]; close = open; display = false
            } else {
                // Consume escaped delimiters together, including \\$ and \\\\.
                let count = char == "\\" && index + 1 < characters.count ? 2 : 1
                output += String(characters[index ..< index + count])
                index += count
                continue
            }

            let start = index + open.count
            var end = start
            var closing: Int?
            while end < characters.count, end - start <= 4096 {
                if !display, characters[end] == "\n" { break }
                if matches(close, at: end) {
                    let validDollar = close != ["$"] || (end > start
                        && !characters[end - 1].isWhitespace
                        && (end + 1 == characters.count || !characters[end + 1].isNumber))
                    if validDollar { closing = end; break }
                }
                end += characters[end] == "\\" && end + 1 < characters.count ? 2 : 1
            }
            guard let closing, closing > start, formulas.count < 64 else {
                output += String(open)
                index += open.count
                continue
            }
            let tex = String(characters[start ..< closing])
            guard !tex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                output += String(open)
                index += open.count
                continue
            }
            let endIndex = closing + close.count
            let expression = MathExpression(source: String(characters[index ..< endIndex]), tex: tex, display: display)
            let token = prefix + String(formulas.count) + "\u{E001}"
            formulas.append((token, expression))
            if display, !output.isEmpty, !output.hasSuffix("\n") { output += "\n" }
            output += token
            if display, endIndex < characters.count, characters[endIndex] != "\n" { output += "\n" }
            index = endIndex
        }
        return Document(text: output, formulas: formulas)
    }
}
