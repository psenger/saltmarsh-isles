import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

/// The Cards tab: the hand grouped by card, and the cards played so far as pills.
@MainActor @Suite struct CardsScreenTests {
    func viewModel(_ s: GameState) -> GameViewModel {
        let vm = GameViewModel(store: InMemoryGameStore(), pacing: NoPacing()) { _, _ in nil }
        vm.load(s)
        return vm
    }

    @Test func noPlayedLineBeforeAnyCardIsPlayed() {
        var s = TestGames.rolled(8)
        s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: -1)]
        #expect(viewModel(s).screen.playedPills == [])
    }
    @Test func rowsAreGroupedInTypeOrder() {
        var s = TestGames.rolled(8)
        s.players[0].devCards = [.victoryPoint, .cornerMarket, .knight, .bumperHarvest, .roadCrew, .knight].map { DevCard(type: $0, boughtOnTurn: -1) }
        let rows = viewModel(s).screen.devCards
        #expect(rows.map(\.type) == [.knight, .roadCrew, .bumperHarvest, .cornerMarket, .victoryPoint])
        #expect(rows.map(\.count) == [2, 1, 1, 1, 1])
    }
    @Test func groupedRowPlaysAPlayableCopy() {
        var s = TestGames.rolled(8)
        s.players[0].devCards = [DevCard(type: .knight, boughtOnTurn: s.turn), DevCard(type: .knight, boughtOnTurn: -1)]
        let vm = viewModel(s)
        let row = vm.screen.devCards[0]
        #expect(row.index == 1)
        #expect(row.note == nil)
        #expect(row.playEnabled)
        vm.playCard(row.index)
        #expect(vm.state?.players[0].devCards == [DevCard(type: .knight, boughtOnTurn: s.turn)])
    }
}
