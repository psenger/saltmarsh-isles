import Foundation
import Testing
import SaltmarshEngine
@testable import SaltmarshGame

@Suite struct ParserTests {
    static let featurePath = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("saltmarsh-isles.feature").path

    @Test func parsesTheRealFile() throws {
        let feature = try GherkinParser.parse(try String(contentsOfFile: Self.featurePath, encoding: .utf8))
        #expect(feature.name == "Saltmarsh Isles pass-and-play game")
        #expect(feature.background.map(\.text) == ["the game page is open"])
        #expect(feature.rules.count == 16)
        let scenarios = feature.rules.flatMap(\.scenarios)
        #expect(scenarios.count == 111)                                   // 89 scenarios, 8 outlines expanded to 30 rows
        #expect(scenarios.filter { $0.name.hasSuffix("(row 1)") }.count == 8)
    }
    @Test func ruleBackgroundIsPrepended() throws {
        let text = """
        Feature: F
          Background:
            Given one
          Rule: R
            Background:
              Given two
            Scenario: S
              When three
              Then four
              And five
        """
        let f = try GherkinParser.parse(text)
        let s = f.rules[0].scenarios[0]
        #expect(f.rules[0].background.map(\.text) == ["two"])
        #expect(s.steps.map(\.text) == ["three", "four", "five"]); #expect(s.steps.map(\.keyword) == ["When", "Then", "Then"])
        #expect(s.rule == "R"); #expect(s.line == 7)
    }
    @Test func outlinesTagsAndTables() throws {
        let text = """
        Feature: F
          Rule: R
            @ui
            Scenario Outline: Count <n>
              Given <n> things called <what>
              Then a table
                | a | b |
                | 1 | 2 |

              Examples:
                | n | what   |
                | 2 | apples |
                | 3 | pears  |
        """
        let f = try GherkinParser.parse(text)
        let s = f.rules[0].scenarios
        #expect(s.count == 2); #expect(s[0].name == "Count 2 (row 1)"); #expect(s[1].name == "Count 3 (row 2)")
        #expect(s[0].steps[0].text == "2 things called apples"); #expect(s[1].steps[0].text == "3 things called pears")
        #expect(s[0].tags == ["ui"]); #expect(s[0].steps[1].table == [["a", "b"], ["1", "2"]])
    }
    @Test func errorsOnMalformedInput() {
        #expect(throws: GherkinParser.Error.self) { try GherkinParser.parse("Feature: F\n  Given a step before any scenario\n") }
        #expect(throws: GherkinParser.Error.self) { try GherkinParser.parse("Feature: F\n  Scenario Outline: S\n    Given x\n    Examples:\n") }
        #expect(throws: GherkinParser.Error.self) { try GherkinParser.parse("Feature: F\n  Wibble: nope\n") }
    }
    @MainActor @Test func registryMatchesAndReportsUnmatched() async throws {
        let registry = StepRegistry()
        var seen: [String] = []
        registry.given("(\\d+) things called (\\w+)") { _, captures, _ in seen.append("\(captures[0]):\(captures[1])") }
        let world = World()
        try await registry.run(Step(keyword: "Given", text: "2 things called apples", table: nil, line: 1), in: world)
        #expect(seen == ["2:apples"])
        await #expect(throws: StepError.unmatched("nothing like this")) {
            try await registry.run(Step(keyword: "Then", text: "nothing like this", table: nil, line: 2), in: world)
        }
        registry.given("(\\d+) things.*") { _, _, _ in }
        await #expect(throws: StepError.self) {
            try await registry.run(Step(keyword: "Given", text: "2 things called apples", table: nil, line: 3), in: world)
        }
    }
}
