import Testing
@testable import SaltmarshEngine

@Suite struct PackageTests {
    @Test func engineModuleLinks() { _ = Engine.self }
}
