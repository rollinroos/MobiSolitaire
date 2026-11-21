import Foundation
import Observation

/// Owns the current game, persists it, and tracks UI-facing side info.
@MainActor
@Observable
final class GameStore {
    private(set) var game: Klondike
    /// Cards that changed pile in the most recent action; drawn on top while they fly.
    private(set) var lastMoved: Set<String> = []
    /// Seconds played. Kept outside `game` so the once-a-second tick only redraws
    /// the clock, not all 52 cards that depend on `game`.
    private(set) var elapsed: Int

    private static let gameKey = "solitaire.game.v1"
    private static let drawKey = "solitaire.drawCount"

    init() {
        let loaded: Klondike
        if let data = UserDefaults.standard.data(forKey: Self.gameKey),
           let saved = try? JSONDecoder().decode(Klondike.self, from: data) {
            loaded = saved
        } else {
            loaded = Klondike(drawCount: UserDefaults.standard.integer(forKey: Self.drawKey))
        }
        game = loaded
        elapsed = loaded.elapsed
    }

    /// The clock only runs between the first move and the win.
    var clockRunning: Bool { game.started && !game.won }

    func newGame(drawCount: Int) {
        UserDefaults.standard.set(drawCount, forKey: Self.drawKey)
        game = Klondike(drawCount: drawCount)
        elapsed = 0
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
        perform { $0.autoMove(from: from, index: index) }
    }

    @discardableResult
    func autoFinishStep() -> Bool {
        perform { $0.autoFinishStep() }
    }

    /// Advances the clock. Deliberately doesn't save: the time is written with each
    /// move and when the app leaves the foreground, not every few seconds.
    func tick() {
        guard clockRunning else { return }
        elapsed += 1
    }

    func save() {
        var snapshot = game
        snapshot.elapsed = elapsed
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
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
