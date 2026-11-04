import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

@Suite struct StoreTests {
    @Test func inMemoryRoundTrip() throws {
        let store = InMemoryGameStore(); #expect(try store.load() == nil)
        let s = TestGames.afterSetup(); try store.save(s)
        #expect(try store.load() == s); #expect(store.saveCount == 1)
        try store.clear(); #expect(try store.load() == nil)
    }
    @Test func noPacingReturnsAtOnce() async {
        let start = ContinuousClock.now
        await NoPacing().pause()
        #expect(ContinuousClock.now - start < .milliseconds(50))
    }
}
