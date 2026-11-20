import Foundation
import Observation

/// Owns the current game, persists it, and tracks UI-facing side info.
@MainActor
@Observable
final class GameStore {
    private(set) var game: Klondike
    /// Cards that changed pile in the most recent action; drawn on top while they fly.
    private(set) var lastMoved: Set<String> = []
    /// Bumped whenever a move is rejected, to trigger feedback.
    private(set) var rejections = 0
    var isActive = true

    private static let gameKey = "solitaire.game.v1"
    private static let drawKey = "solitaire.drawCount"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.gameKey),
           let saved = try? JSONDecoder().decode(Klondike.self, from: data) {
            game = saved
        } else {
            game = Klondike(drawCount: UserDefaults.standard.integer(forKey: Self.drawKey))
        }
    }

    func newGame(drawCount: Int) {
        UserDefaults.standard.set(drawCount, forKey: Self.drawKey)
        game = Klondike(drawCount: drawCount)
        lastMoved = []
        save()
    }

    func draw() {
        perform { $0.draw() }
    }

    func undo() {
        perform { $0.undo() }
    }

    @discardableResult
    func move(from: PileRef, index: Int, to: PileRef) -> Bool {
        perform { $0.move(from: from, index: index, to: to) }
    }

    @discardableResult
    func autoMove(from: PileRef, index: Int) -> Bool {
        let moved = perform { $0.autoMove(from: from, index: index) }
        if !moved { rejections += 1 }
        return moved
    }

    @discardableResult
    func autoFinishStep() -> Bool {
        perform { $0.autoFinishStep() }
    }

    func reject() {
        rejections += 1
    }

    func tick() {
        guard isActive, game.started, !game.won else { return }
        game.elapsed += 1
        if game.elapsed % 5 == 0 { save() }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(game) else { return }
        UserDefaults.standard.set(data, forKey: Self.gameKey)
    }

    @discardableResult
    private func perform(_ action: (inout Klondike) -> Bool) -> Bool {
        let before = game.table.locations()
        var next = game
        guard action(&next) else { return false }
        let after = next.table.locations()
        lastMoved = Set(after.compactMap { id, pile in before[id] == pile ? nil : id })
        game = next
        save()
        return true
    }
}
