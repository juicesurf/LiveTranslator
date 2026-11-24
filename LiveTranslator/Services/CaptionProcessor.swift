import Foundation

struct CaptionUnit: Identifiable, Equatable, Sendable {
    let id: Int
    var text: String
    var complete: Bool
}

/// Reconciles rolling, word-based snapshots before splitting into complete sentences.
/// Sentence identities survive corrections; identical occurrences remain distinct.
struct CaptionProcessor {
    private var document: [String] = []
    private var previous: [String] = []
    private var snapshotStart = 0
    private var previousUnits: [CaptionUnit] = []
    private var nextID = 0

    mutating func consume(_ snapshot: String) -> [CaptionUnit] {
        let words = snapshot.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !words.isEmpty else { return units() }
        if words == previous { return units() }
        if !previous.isEmpty {
            let old = previous.map(Self.matchingToken)
            let new = words.map(Self.matchingToken)
            let common = zip(old, new).prefix(while: { $0 == $1 }).count
            if common >= min(3, old.count) {
                // Same window, including a corrected/extended tail.
            } else if let offset = Self.overlapStart(old: old, new: new) {
                snapshotStart += offset
            } else {
                let matching = zip(old, new).filter { $0 == $1 }.count
                if matching * 2 < min(old.count, new.count) {
                    snapshotStart = document.count
                }
            }
        }
        document = Array(document.prefix(snapshotStart)) + words
        previous = words
        return units()
    }

    private static func matchingToken(_ word: String) -> String {
        word.lowercased().trimmingCharacters(in: .punctuationCharacters)
    }

    /// Semi-global edit alignment: old suffix against new prefix, tolerating ASR edits.
    /// Only adjacent windows are matched; this is not global sentence de-duplication.
    private static func overlapStart(old: [String], new: [String]) -> Int? {
        struct Cell {
            var edits: Int
            var matches: Int
            var start: Int
        }
        // Bound work for unusually large accessibility snapshots.
        let base = max(0, old.count - 400)
        let old = Array(old.suffix(400))
        let new = Array(new.prefix(420))
        var row = (0...new.count).map { Cell(edits: $0, matches: 0, start: 0) }
        for i in 1...old.count {
            var next = [Cell(edits: 0, matches: 0, start: i)]
            for j in 1...new.count {
                let equal = old[i - 1] == new[j - 1]
                let diagonal = Cell(edits: row[j - 1].edits + (equal ? 0 : 1),
                                    matches: row[j - 1].matches + (equal ? 1 : 0), start: row[j - 1].start)
                let deletion = Cell(edits: row[j].edits + 1, matches: row[j].matches, start: row[j].start)
                let insertion = Cell(edits: next[j - 1].edits + 1, matches: next[j - 1].matches, start: next[j - 1].start)
                var best = diagonal
                for candidate in [deletion, insertion] {
                    if candidate.edits < best.edits || (candidate.edits == best.edits && candidate.matches > best.matches) {
                        best = candidate
                    }
                }
                next.append(best)
            }
            row = next
        }
        let candidates = row.dropFirst().filter {
            ($0.edits == 0 && $0.matches > 0) ||
            ($0.matches >= 2 && $0.matches >= $0.edits * 2 && $0.edits <= 4)
        }
        return candidates.max {
            let lhs = $0.matches - 2 * $0.edits
            let rhs = $1.matches - 2 * $1.edits
            return lhs == rhs ? $0.matches < $1.matches : lhs < rhs
        }.map { base + $0.start }
    }

    // Conservative English boundary rules: uncertain abbreviation tails remain pending.
    private func endsSentence(_ word: String, next: String?) -> Bool {
        let closing = CharacterSet(charactersIn: "\"'”’)]}")
        let token = word.trimmingCharacters(in: closing)
        guard let last = token.last else { return false }
        if last == "?" || last == "!" { return true }
        guard last == "." else { return false }
        let lower = token.lowercased()
        let abbreviations: Set<String> = ["mr.", "mrs.", "ms.", "dr.", "prof.", "sr.", "jr.", "st.", "vs.", "e.g.", "i.e.", "fig.", "no."]
        if abbreviations.contains(lower) { return false }
        // Initials and dotted acronyms (J., U.S., Ph.D.) are ambiguous at snapshot end.
        let parts = token.dropLast().split(separator: ".")
        if parts.allSatisfy({ $0.count == 1 && $0.first?.isLetter == true }) { return false }
        if lower == "ph.d." { return false }
        // A decimal is internal punctuation; a final period after it can close a sentence.
        if lower.hasSuffix("...") { return false }
        if ["etc.", "inc.", "ltd."].contains(lower),
           next == nil || next?.first?.isLowercase == true { return false }
        return true
    }

    private mutating func units() -> [CaptionUnit] {
        var output: [CaptionUnit] = []
        var start = 0
        for index in document.indices {
            if endsSentence(document[index], next: index + 1 < document.count ? document[index + 1] : nil) {
                output.append(CaptionUnit(id: start, text: document[start...index].joined(separator: " "), complete: true))
                start = index + 1
            }
        }
        if start < document.count {
            output.append(CaptionUnit(id: start, text: document[start...].joined(separator: " "), complete: false))
        }
        // Reserve identities of unchanged occurrences before assigning corrected ones.
        var assigned: [Int: Int] = [:]
        var used: Set<Int> = []
        var searchStart = 0
        for index in output.indices {
            if let oldIndex = previousUnits.indices.dropFirst(searchStart).first(where: {
                previousUnits[$0].text == output[index].text
            }) {
                assigned[index] = previousUnits[oldIndex].id
                used.insert(previousUnits[oldIndex].id)
                searchStart = oldIndex + 1
            }
        }
        for index in output.indices where assigned[index] == nil {
            if index < previousUnits.count, !used.contains(previousUnits[index].id) {
                assigned[index] = previousUnits[index].id
                used.insert(previousUnits[index].id)
            } else {
                assigned[index] = nextID
                nextID += 1
            }
        }
        previousUnits = output.enumerated().map {
            CaptionUnit(id: assigned[$0.offset]!, text: $0.element.text, complete: $0.element.complete)
        }
        return previousUnits
    }
}
