import Foundation

enum StepError: Error, Equatable, CustomStringConvertible {
    case unmatched(String)
    case ambiguous(String, patterns: [String])
    case failed(String)

    var description: String {
        switch self {
        case .unmatched(let text): "no step definition matches \"\(text)\""
        case .ambiguous(let text, let patterns): "step \"\(text)\" matches several definitions: \(patterns)"
        case .failed(let message): message
        }
    }
}

/// Regex-matched step definitions. A pattern is anchored to the whole step text; captures are
/// handed to the body as strings, with the step's data table when it has one.
@MainActor
final class StepRegistry {
    typealias Body = @MainActor (World, [String], [[String]]?) async throws -> Void

    private struct Definition {
        let keyword: String
        let pattern: String
        let regex: NSRegularExpression
        let body: Body
    }

    private var definitions: [Definition] = []

    func given(_ pattern: String, _ body: @escaping Body) { add("Given", pattern, body) }
    func when(_ pattern: String, _ body: @escaping Body) { add("When", pattern, body) }
    func then(_ pattern: String, _ body: @escaping Body) { add("Then", pattern, body) }

    private func add(_ keyword: String, _ pattern: String, _ body: @escaping Body) {
        let regex = try! NSRegularExpression(pattern: "^(?:\(pattern))$")
        definitions.append(Definition(keyword: keyword, pattern: pattern, regex: regex, body: body))
    }

    /// Runs the one definition matching the step. When several match, the one registered under the
    /// step's own keyword wins (a "Given X holds 4 timber" sets a hand; a "Then X holds 4 timber" checks it).
    func run(_ step: Step, in world: World) async throws {
        let text = step.text
        let range = NSRange(text.startIndex..., in: text)
        var matches = definitions.compactMap { d -> (Definition, NSTextCheckingResult)? in
            d.regex.firstMatch(in: text, range: range).map { (d, $0) }
        }
        if matches.count > 1 {
            let sameKeyword = matches.filter { $0.0.keyword == step.keyword }
            if sameKeyword.count == 1 { matches = sameKeyword }
        }
        guard let (definition, match) = matches.first else { throw StepError.unmatched(text) }
        if matches.count > 1 { throw StepError.ambiguous(text, patterns: matches.map(\.0.pattern)) }
        let captures = (1..<match.numberOfRanges).map { i -> String in
            let r = match.range(at: i)
            return r.location == NSNotFound ? "" : String(text[Range(r, in: text)!])
        }
        try await definition.body(world, captures, step.table)
    }
}
