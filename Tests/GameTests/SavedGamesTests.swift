import Foundation
import Testing
import SaltmarshEngine
import SaltmarshTestSupport
@testable import SaltmarshGame

@MainActor @Suite struct SavedGamesTests {
    func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "saves-\(UUID().uuidString)")
    }
    func model(saves: SaveSlots = InMemorySaveSlots(), store: InMemoryGameStore = InMemoryGameStore()) -> GameViewModel {
        let vm = GameViewModel(store: store, pacing: NoPacing(), saves: saves) { _, _ in nil }
        vm.load(TestGames.rolled(8))
        return vm
    }
    /// Fills every slot, oldest first, so "Save 5" is the newest.
    func filled(_ slots: SaveSlots) throws {
        for i in 1...SaveLimit.maxSaves {
            try slots.write(name: "Save \(i)", state: TestGames.fresh(), now: Date(timeIntervalSince1970: Double(i)))
        }
    }

    @Test func savesRoundTripThroughARealFolderNewestFirst() throws {
        let folder = temporaryFolder(), state = TestGames.rolled(8)
        defer { try? FileManager.default.removeItem(at: folder) }
        let slots = FileSaveSlots(directory: folder)
        let old = try slots.write(name: "Old", state: TestGames.fresh(), now: Date(timeIntervalSince1970: 1))
        let new = try slots.write(name: "New", state: state, now: Date(timeIntervalSince1970: 2))
        let reopened = FileSaveSlots(directory: folder)
        #expect(reopened.list() == [new, old])
        #expect(try reopened.load(id: new.id).state == state)
    }
    @Test func aSixthSaveIsRefusedAndLeavesTheFiveIntact() throws {
        let slots = InMemorySaveSlots()
        try filled(slots)
        let before = slots.list()
        #expect(throws: SaveError.full) { try slots.write(name: "Sixth", state: TestGames.fresh()) }
        #expect(slots.list() == before)
    }
    @Test func replacingKeepsTheCountAtFive() throws {
        let slots = InMemorySaveSlots()
        try filled(slots)
        let target = slots.list()[2]
        let saved = try slots.write(name: "Replacement", state: TestGames.fresh(), replacing: target.id)
        #expect(saved.id == target.id)
        #expect(slots.list().count == SaveLimit.maxSaves)
        #expect(slots.list().map(\.name).contains("Replacement"))
        #expect(!slots.list().map(\.name).contains(target.name))
    }
    @Test func replacingASaveThatIsGoneIsRefused() {
        #expect(throws: SaveError.notFound) { try InMemorySaveSlots().write(name: "A", state: TestGames.fresh(), replacing: UUID()) }
    }
    @Test func deletingRemovesOnlyThatSaveFromARealFolder() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let slots = FileSaveSlots(directory: folder)
        let keep = try slots.write(name: "Keep", state: TestGames.fresh())
        let gone = try slots.write(name: "Gone", state: TestGames.fresh())
        try slots.remove(id: gone.id)
        #expect(FileSaveSlots(directory: folder).list() == [keep])
        #expect(throws: SaveError.notFound) { try slots.load(id: gone.id) }
    }
    @Test func deletingMakesRoomWhenAllFiveAreUsed() throws {
        let saves = InMemorySaveSlots(), vm = model(saves: saves)
        try filled(saves)
        try vm.deleteSavedGame(id: vm.savedGames()[0].id)
        #expect(vm.savedGames().count == SaveLimit.maxSaves - 1)
        try vm.saveGame(named: "Now there is room")
        #expect(vm.savedGames().count == SaveLimit.maxSaves)
    }
    @Test func deletingLeavesTheGameInProgressAlone() throws {
        let store = InMemoryGameStore(), vm = model(store: store)
        let id = try vm.saveGame(named: "Gone").id, before = vm.state
        try vm.deleteSavedGame(id: id)
        #expect(vm.state == before)
        #expect(try store.load() == before)
    }
    @Test func namesAreClippedAndCannotBeBlank() throws {
        let slots = InMemorySaveSlots()
        let long = String(repeating: "x", count: 40)
        #expect(try slots.write(name: "  \(long)  ", state: TestGames.fresh()).name.count == SaveLimit.maxNameLength)
        #expect(throws: SaveError.blankName) { try slots.write(name: "   ", state: TestGames.fresh()) }
    }
    @Test func aCorruptFileIsSkipped() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let slots = FileSaveSlots(directory: folder)
        let good = try slots.write(name: "Good", state: TestGames.fresh())
        try Data("not a game".utf8).write(to: folder.appending(path: "\(UUID().uuidString).json"))
        #expect(slots.list() == [good])
    }
    @Test func savingLeavesTheCurrentGameAloneAndTheAutosaveIsNotOneOfTheFive() throws {
        let saves = InMemorySaveSlots(), store = InMemoryGameStore(), vm = model(saves: saves, store: store)
        let before = vm.state
        try vm.saveGame(named: "Keep")
        #expect(vm.state == before)
        #expect(try store.load() == before)
        #expect(vm.savedGames().map(\.name) == ["Keep"])
    }
    @Test func loadingRestoresTheStateAndUpdatesTheAutosave() throws {
        let store = InMemoryGameStore(), vm = model(store: store)
        let saved = vm.state
        let id = try vm.saveGame(named: "Before").id
        vm.endTurn()
        #expect(vm.state != saved)
        try vm.loadGame(id: id)
        #expect(vm.state == saved)
        #expect(try store.load() == saved)
    }
    @Test func loadingAGameWithTwoHumansStartsOnTheHandover() throws {
        let vm = model()
        vm.revealHand()
        let id = try vm.saveGame(named: "Hidden").id
        vm.revealHand()
        #expect(vm.screen.handover == nil)
        try vm.loadGame(id: id)
        #expect(vm.screen.handover != nil)
    }
    @Test func aFinishedGameCannotBeSaved() throws {
        var s = TestGames.rolled(8)
        #expect(model().screen.buttons[Strings.saveGame] == true)
        s.phase = .gameOver(winner: 0)
        let vm = model()
        vm.load(s)
        #expect(vm.screen.buttons[Strings.saveGame] == false)
        #expect(throws: SaveError.noGame) { try vm.saveGame(named: "Done") }
    }
    @Test func theSuggestedNameUsesTheTurn() {
        var s = TestGames.rolled(8)
        s.turn = 27
        let vm = model()
        vm.load(s)
        #expect(vm.suggestedSaveName == "Turn 28")
    }
}
