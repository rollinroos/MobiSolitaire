import Foundation

/// The cards on the table, grouped into piles.
struct Table: Codable, Sendable, Equatable {
    var stock: [Card] = []
    var waste: [Card] = []
    var foundations: [[Card]] = Array(repeating: [], count: 4)
    var tableau: [[Card]] = Array(repeating: [], count: 7)

    subscript(ref: PileRef) -> [Card] {
        get {
            switch ref {
            case .stock: stock
            case .waste: waste
            case .foundation(let i): foundations[i]
            case .tableau(let i): tableau[i]
            }
        }
        set {
            switch ref {
            case .stock: stock = newValue
            case .waste: waste = newValue
            case .foundation(let i): foundations[i] = newValue
            case .tableau(let i): tableau[i] = newValue
            }
        }
    }

    static func dealt() -> Table {
        var deck = Suit.allCases.flatMap { suit in (1...13).map { Card(suit: suit, rank: $0) } }.shuffled()
        var table = Table()
        for col in 0..<7 {
            for row in 0...col {
                var card = deck.removeLast()
                card.faceUp = row == col
                table.tableau[col].append(card)
            }
        }
        table.stock = deck
        return table
    }

    /// Which pile every card currently sits in.
    func locations() -> [String: PileRef] {
        var map: [String: PileRef] = [:]
        for ref in [PileRef.stock, .waste] + PileRef.dropTargets {
            for card in self[ref] { map[card.id] = ref }
        }
        return map
    }
}

/// Klondike rules engine. Pure value type, no UI.
struct Klondike: Codable, Sendable {
    private(set) var table: Table
    private(set) var drawCount: Int
    private(set) var moves = 0
    private(set) var started = false
    private(set) var won = false
    var elapsed = 0
    private var history: [Snapshot] = []

    private struct Snapshot: Codable, Sendable {
        var table: Table
        var moves: Int
    }

    private static let maxHistory = 100

    init(drawCount: Int = 1) {
        self.drawCount = drawCount == 3 ? 3 : 1
        self.table = .dealt()
    }

    // MARK: History

    var canUndo: Bool { !history.isEmpty && !won }

    private mutating func record() {
        history.append(Snapshot(table: table, moves: moves))
        if history.count > Self.maxHistory { history.removeFirst() }
        started = true
    }

    @discardableResult
    mutating func undo() -> Bool {
        guard canUndo, let snapshot = history.popLast() else { return false }
        table = snapshot.table
        moves = snapshot.moves
        return true
    }

    // MARK: Moves

    /// Flip from stock to waste, or recycle the waste when the stock is empty.
    @discardableResult
    mutating func draw() -> Bool {
        guard !won else { return false }
        if !table.stock.isEmpty {
            record()
            for _ in 0..<min(drawCount, table.stock.count) {
                var card = table.stock.removeLast()
                card.faceUp = true
                table.waste.append(card)
            }
        } else if !table.waste.isEmpty {
            record()
            table.stock = table.waste.reversed().map { card in
                var card = card
                card.faceUp = false
                return card
            }
            table.waste = []
        } else {
            return false
        }
        moves += 1
        return true
    }

    func canPick(_ ref: PileRef, _ index: Int) -> Bool {
        if case .stock = ref { return false }
        let pile = table[ref]
        guard pile.indices.contains(index), pile[index].faceUp else { return false }
        guard case .tableau = ref else { return index == pile.count - 1 }
        for k in index..<(pile.count - 1) where !pile[k + 1].stacks(on: pile[k]) {
            return false
        }
        return true
    }

    func canPlace(_ cards: ArraySlice<Card>, on ref: PileRef) -> Bool {
        guard let first = cards.first else { return false }
        let top = table[ref].last
        switch ref {
        case .foundation:
            guard cards.count == 1 else { return false }
            if let top { return top.suit == first.suit && first.rank == top.rank + 1 }
            return first.rank == 1
        case .tableau:
            if let top { return top.faceUp && first.stacks(on: top) }
            return first.rank == 13
        case .stock, .waste:
            return false
        }
    }

    func canMove(from: PileRef, index: Int, to: PileRef) -> Bool {
        from != to && canPick(from, index) && canPlace(table[from][index...], on: to)
    }

    @discardableResult
    mutating func move(from: PileRef, index: Int, to: PileRef) -> Bool {
        guard !won, canMove(from: from, index: index, to: to) else { return false }
        record()
        let cards = table[from][index...]
        table[from].removeSubrange(index...)
        table[to].append(contentsOf: cards)
        if case .tableau = from, let last = table[from].indices.last, !table[from][last].faceUp {
            table[from][last].faceUp = true
        }
        moves += 1
        won = table.foundations.allSatisfy { $0.count == 13 }
        return true
    }

    /// Best destination for a tap: foundation first, then a non-empty column,
    /// then an empty column (unless the card already starts a column).
    func autoTarget(from: PileRef, index: Int) -> PileRef? {
        let count = table[from].count - index
        if count == 1 {
            for i in 0..<4 where canMove(from: from, index: index, to: .foundation(i)) {
                return .foundation(i)
            }
        }
        var alreadyAtColumnBase = false
        if case .tableau = from, index == 0 { alreadyAtColumnBase = true }
        var empty: PileRef?
        for i in 0..<7 where canMove(from: from, index: index, to: .tableau(i)) {
            if !table.tableau[i].isEmpty { return .tableau(i) }
            if empty == nil && !alreadyAtColumnBase { empty = .tableau(i) }
        }
        return empty
    }

    @discardableResult
    mutating func autoMove(from: PileRef, index: Int) -> Bool {
        guard let to = autoTarget(from: from, index: index) else { return false }
        return move(from: from, index: index, to: to)
    }

    /// With the stock spent and every card face up, the game is solved.
    var canAutoFinish: Bool {
        !won && table.stock.isEmpty && table.waste.isEmpty &&
            table.tableau.allSatisfy { $0.allSatisfy(\.faceUp) }
    }

    /// Moves the lowest available tableau card to a foundation.
    @discardableResult
    mutating func autoFinishStep() -> Bool {
        var best: (rank: Int, from: PileRef, index: Int, to: PileRef)?
        for i in 0..<7 {
            guard let top = table.tableau[i].last else { continue }
            if let best, best.rank <= top.rank { continue }
            let index = table.tableau[i].count - 1
            for f in 0..<4 where canMove(from: .tableau(i), index: index, to: .foundation(f)) {
                best = (top.rank, .tableau(i), index, .foundation(f))
                break
            }
        }
        guard let best else { return false }
        return move(from: best.from, index: best.index, to: best.to)
    }
}
