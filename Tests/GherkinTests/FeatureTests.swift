import Foundation
import Testing

/// Runs every scenario of `saltmarsh-isles.feature` (except those tagged @ui) as its own test case.
@Suite struct FeatureTests {
    static func scenarios() -> [Scenario] {
        let feature = try! GherkinParser.parse(try! String(contentsOfFile: ParserTests.featurePath, encoding: .utf8))
        return feature.rules.flatMap { rule in
            rule.scenarios.filter { !$0.tags.contains("ui") }.map { scenario in
                var s = scenario
                s.steps = feature.background + rule.background + scenario.steps
                return s
            }
        }
    }

    @MainActor @Test(arguments: scenarios())
    func scenario(_ scenario: Scenario) async {
        let world = World()
        let registry = StepLibrary.make()
        for step in scenario.steps {
            do {
                try await registry.run(step, in: world)
            } catch {
                Issue.record("\(scenario.rule) / \(scenario.name): \(step.keyword) \(step.text) (line \(step.line)) → \(error)")
                return
            }
        }
    }
}
