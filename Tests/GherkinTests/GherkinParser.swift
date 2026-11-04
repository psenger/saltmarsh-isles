import Foundation
import Testing

struct Step: Equatable, Sendable {
    /// Given, When or Then; And/But take the previous step's keyword.
    var keyword: String
    var text: String
    var table: [[String]]?
    var line: Int
}

struct Scenario: Equatable, Sendable, CustomTestStringConvertible {
    var name: String
    var rule: String
    var tags: Set<String>
    var steps: [Step]
    var line: Int
    var testDescription: String { "\(rule) / \(name)" }
}

struct Rule: Equatable, Sendable {
    var name: String
    var background: [Step]
    var scenarios: [Scenario]
}

struct Feature: Equatable, Sendable {
    var name: String
    var background: [Step]
    var rules: [Rule]
}

/// Feature, Rule, Background (both levels), Scenario, Scenario Outline + Examples, tags, tables, comments.
enum GherkinParser {
    enum Error: Swift.Error, Equatable {
        case stepOutsideScenario(line: Int)
        case examplesWithoutTable(line: Int)
        case unknownKeyword(String, line: Int)
        case missingFeature
    }

    private enum Block { case none, featureBackground, ruleBackground, scenario, outline, examples }

    static func parse(_ text: String) throws -> Feature {
        var featureName: String?
        var featureBackground: [Step] = []
        var rules: [Rule] = []
        var currentRule: Rule?
        var block = Block.none
        var pendingTags = Set<String>()
        // The scenario (or outline) being collected.
        var scenarioName = "", scenarioTags = Set<String>(), scenarioSteps: [Step] = [], scenarioLine = 0
        var exampleRows: [[String]] = []
        var lastKeyword = "Given"

        func flushScenario() throws {
            guard block == .scenario || block == .outline || block == .examples else { return }
            let ruleName = currentRule?.name ?? ""
            if block == .scenario {
                currentRule?.scenarios.append(Scenario(name: scenarioName, rule: ruleName, tags: scenarioTags, steps: scenarioSteps, line: scenarioLine))
            } else {
                guard exampleRows.count >= 2 else { throw Error.examplesWithoutTable(line: scenarioLine) }
                let header = exampleRows[0]
                for (rowIndex, row) in exampleRows.dropFirst().enumerated() {
                    func fill(_ s: String) -> String {
                        var out = s
                        for (h, v) in zip(header, row) { out = out.replacingOccurrences(of: "<\(h)>", with: v) }
                        return out
                    }
                    let steps = scenarioSteps.map { Step(keyword: $0.keyword, text: fill($0.text), table: $0.table?.map { $0.map(fill) }, line: $0.line) }
                    currentRule?.scenarios.append(Scenario(name: "\(fill(scenarioName)) (row \(rowIndex + 1))", rule: ruleName, tags: scenarioTags, steps: steps, line: scenarioLine))
                }
            }
            scenarioSteps = []; exampleRows = []; scenarioTags = []
            block = .none
        }
        func flushRule() throws {
            try flushScenario()
            if let r = currentRule { rules.append(r) }
            currentRule = nil
        }
        func addStep(_ keyword: String, _ text: String, line: Int) throws {
            let kw = (keyword == "And" || keyword == "But") ? lastKeyword : keyword
            lastKeyword = kw
            let step = Step(keyword: kw, text: text, table: nil, line: line)
            switch block {
            case .featureBackground: featureBackground.append(step)
            case .ruleBackground: currentRule?.background.append(step)
            case .scenario, .outline: scenarioSteps.append(step)
            default: throw Error.stepOutsideScenario(line: line)
            }
        }
        func addTableRow(_ cells: [String], line: Int) throws {
            switch block {
            case .examples: exampleRows.append(cells)
            case .featureBackground: featureBackground[featureBackground.count - 1].table = (featureBackground.last!.table ?? []) + [cells]
            case .ruleBackground:
                let last = currentRule!.background.count - 1
                currentRule!.background[last].table = (currentRule!.background[last].table ?? []) + [cells]
            case .scenario, .outline:
                guard !scenarioSteps.isEmpty else { throw Error.stepOutsideScenario(line: line) }
                scenarioSteps[scenarioSteps.count - 1].table = (scenarioSteps.last!.table ?? []) + [cells]
            case .none: throw Error.stepOutsideScenario(line: line)
            }
        }

        for (index, raw) in text.components(separatedBy: "\n").enumerated() {
            let line = index + 1
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("@") {
                pendingTags.formUnion(trimmed.split(separator: " ").map { String($0.dropFirst()) })
                continue
            }
            if trimmed.hasPrefix("|") {
                let cells = trimmed.dropFirst().dropLast().components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                try addTableRow(cells, line: line)
                continue
            }
            let parts = trimmed.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            let head = parts[0], rest = parts.count > 1 ? parts[1] : ""
            switch head {
            case "Feature":
                featureName = rest; block = .none
            case "Rule":
                try flushRule(); currentRule = Rule(name: rest, background: [], scenarios: []); block = .none
            case "Background":
                try flushScenario(); block = currentRule == nil ? .featureBackground : .ruleBackground
            case "Scenario", "Example":
                try flushScenario(); block = .scenario; scenarioName = rest; scenarioLine = line; scenarioTags = pendingTags; pendingTags = []
            case "Scenario Outline", "Scenario Template":
                try flushScenario(); block = .outline; scenarioName = rest; scenarioLine = line; scenarioTags = pendingTags; pendingTags = []
            case "Examples", "Scenarios":
                guard block == .outline else { throw Error.unknownKeyword(head, line: line) }
                block = .examples
            default:
                let words = trimmed.split(separator: " ", maxSplits: 1)
                let keyword = String(words[0])
                if ["Given", "When", "Then", "And", "But", "*"].contains(keyword) {
                    try addStep(keyword == "*" ? lastKeyword : keyword, words.count > 1 ? String(words[1]) : "", line: line)
                } else if parts.count > 1, head.split(separator: " ").count <= 3 {
                    throw Error.unknownKeyword(head, line: line)
                } else if block == .none, featureName != nil {
                    continue   // free-text description under Feature: or Rule:
                } else {
                    throw Error.stepOutsideScenario(line: line)
                }
            }
        }
        try flushRule()
        guard let featureName else { throw Error.missingFeature }
        return Feature(name: featureName, background: featureBackground, rules: rules)
    }
}
