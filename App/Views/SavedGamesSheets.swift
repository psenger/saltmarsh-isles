import SwiftUI
import SaltmarshGame

private func dated(_ save: SavedGameSummary) -> String {
    save.savedAt.formatted(date: .abbreviated, time: .shortened)
}

/// One save in a list: its name and when it was saved.
private struct SaveRow: View {
    let save: SavedGameSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(save.name).foregroundStyle(.primary)
            Text(dated(save)).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

/// Names and keeps a copy of the current game. With all saves used, the only way to save is to pick one to replace.
struct SaveGameSheet: View {
    let vm: GameViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saves: [SavedGameSummary] = []
    @State private var replacing: SavedGameSummary?
    @State private var deleting: SavedGameSummary?
    @State private var problem: String?

    private var full: Bool { saves.count >= SaveLimit.maxSaves }
    private var nameIsBlank: Bool { SaveLimit.clipped(name).isEmpty }

    private func save(replacing target: UUID? = nil) {
        do {
            try vm.saveGame(named: name, replacing: target)
            dismiss()
        } catch {
            problem = "That game could not be saved. \(error.localizedDescription)"
        }
    }

    private func delete(_ save: SavedGameSummary) {
        do {
            try vm.deleteSavedGame(id: save.id)
            saves = vm.savedGames()
            problem = nil
        } catch {
            problem = "\"\(save.name)\" could not be deleted. \(error.localizedDescription)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.saveTitle).font(.title2.bold())
            TextField(Strings.saveName, text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("save name")
                .onChange(of: name) { _, typed in
                    if typed.count > SaveLimit.maxNameLength { name = String(typed.prefix(SaveLimit.maxNameLength)) }
                }
            if let problem {
                Text(problem).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            if !saves.isEmpty {
                Text(full ? Strings.savesFull : Strings.tapToReplace).font(.callout).foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(saves) { save in
                            HStack {
                                Button { replacing = save } label: { SaveRow(save: save).padding(.vertical, 6) }
                                    .buttonStyle(.plain)
                                    .disabled(nameIsBlank)
                                    .accessibilityIdentifier("save slot \(save.name)")
                                Button { deleting = save } label: {
                                    Image(systemName: "trash").frame(width: 32, height: 32).contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                                .accessibilityLabel("\(Strings.deleteButton) \(save.name)")
                                .accessibilityIdentifier("delete slot \(save.name)")
                            }
                            Divider()
                        }
                    }
                }
            }
            HStack {
                Button(Strings.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(Strings.saveButton) { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(full || nameIsBlank)
                    .accessibilityIdentifier("save confirm")
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealWidth: 420)
        .onAppear {
            name = vm.suggestedSaveName
            saves = vm.savedGames()
        }
        .alert(replacing.map { Strings.replacePrompt($0.name) } ?? "", isPresented: Binding(get: { replacing != nil }, set: { if !$0 { replacing = nil } }), presenting: replacing) { target in
            Button(Strings.replaceButton, role: .destructive) { save(replacing: target.id) }
            Button(Strings.cancel, role: .cancel) {}
        } message: { _ in
            Text(Strings.replaceWarning)
        }
        .alert(deleting.map { Strings.deletePrompt($0.name) } ?? "", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), presenting: deleting) { target in
            Button(Strings.deleteButton, role: .destructive) { delete(target) }
            Button(Strings.cancel, role: .cancel) {}
        } message: { _ in
            Text(Strings.deleteWarning)
        }
    }
}

/// Lists the saves. Tapping one confirms, because loading replaces the current game.
struct LoadGameSheet: View {
    let vm: GameViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var saves: [SavedGameSummary] = []
    @State private var loading: SavedGameSummary?
    @State private var problem: String?

    private func load(_ save: SavedGameSummary) {
        do {
            try vm.loadGame(id: save.id)
            dismiss()
        } catch {
            problem = "\"\(save.name)\" could not be loaded. \(error.localizedDescription)"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Strings.loadTitle).font(.title2.bold())
            if let problem {
                Text(problem).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            if saves.isEmpty {
                Text(Strings.noSavedGames).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(saves) { save in
                            Button { loading = save } label: { SaveRow(save: save).padding(.vertical, 6) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("load slot \(save.name)")
                            Divider()
                        }
                    }
                }
            }
            HStack {
                Spacer()
                Button(Strings.cancel) { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealWidth: 420)
        .onAppear { saves = vm.savedGames() }
        .alert(loading.map { Strings.loadPrompt($0.name) } ?? "", isPresented: Binding(get: { loading != nil }, set: { if !$0 { loading = nil } }), presenting: loading) { save in
            Button(Strings.loadButton) { load(save) }
            Button(Strings.cancel, role: .cancel) {}
        } message: { _ in
            Text(Strings.loadWarning)
        }
    }
}
