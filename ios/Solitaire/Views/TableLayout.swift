import CoreGraphics

struct CardPlacement: Identifiable {
    let card: Card
    let pile: PileRef
    let index: Int
    let center: CGPoint
    let z: Double

    var id: String { card.id }
}

/// Geometry of the table for a given container size.
struct TableLayout {
    let cardSize: CGSize
    let gap: CGFloat
    private let columnX: [CGFloat]
    private let tableauTop: CGFloat
    private let availableFanHeight: CGFloat

    private var fanUp: CGFloat { cardSize.height * 0.28 }
    private var fanDown: CGFloat { cardSize.height * 0.12 }
    private var wasteFan: CGFloat { cardSize.width * 0.3 }

    init(size: CGSize) {
        let margin: CGFloat = 8
        let gap: CGFloat = 6
        let width = max(20, min((size.width - 2 * margin - 6 * gap) / 7, 100))
        let height = width * 1.4
        let total = 7 * width + 6 * gap
        let x0 = (size.width - total) / 2 + width / 2
        let top = height + gap * 3
        self.gap = gap
        cardSize = CGSize(width: width, height: height)
        columnX = (0..<7).map { x0 + CGFloat($0) * (width + gap) }
        tableauTop = top
        availableFanHeight = max(0, size.height - top - height)
    }

    var cornerRadius: CGFloat { cardSize.width * 0.12 }

    func slotCenter(_ pile: PileRef) -> CGPoint {
        let topY = cardSize.height / 2
        switch pile {
        case .stock: return CGPoint(x: columnX[0], y: topY)
        case .waste: return CGPoint(x: columnX[1], y: topY)
        case .foundation(let i): return CGPoint(x: columnX[3 + i], y: topY)
        case .tableau(let i): return CGPoint(x: columnX[i], y: tableauTop + cardSize.height / 2)
        }
    }

    /// Vertical offsets for each card in a tableau column, squeezed to fit the screen.
    private func tableauOffsets(_ column: [Card]) -> [CGFloat] {
        guard !column.isEmpty else { return [] }
        let steps = column.dropLast().map { $0.faceUp ? fanUp : fanDown }
        let needed = steps.reduce(0, +)
        let scale = needed > availableFanHeight && needed > 0 ? availableFanHeight / needed : 1
        var offsets: [CGFloat] = [0]
        for step in steps { offsets.append(offsets.last! + step * scale) }
        return offsets
    }

    func placements(for table: Table, drawCount: Int) -> [CardPlacement] {
        var out: [CardPlacement] = []
        out.reserveCapacity(52)

        let stockCenter = slotCenter(.stock)
        for (k, card) in table.stock.enumerated() {
            out.append(.init(card: card, pile: .stock, index: k, center: stockCenter, z: Double(k)))
        }

        let wasteCenter = slotCenter(.waste)
        let shown = min(drawCount == 3 ? 3 : 1, table.waste.count)
        let firstShown = table.waste.count - shown
        for (k, card) in table.waste.enumerated() {
            let dx = k >= firstShown ? CGFloat(k - firstShown) * wasteFan : 0
            out.append(.init(card: card, pile: .waste, index: k,
                             center: CGPoint(x: wasteCenter.x + dx, y: wasteCenter.y), z: 100 + Double(k)))
        }

        for (i, pile) in table.foundations.enumerated() {
            let center = slotCenter(.foundation(i))
            for (k, card) in pile.enumerated() {
                out.append(.init(card: card, pile: .foundation(i), index: k, center: center, z: 200 + Double(k)))
            }
        }

        for (i, column) in table.tableau.enumerated() {
            let base = slotCenter(.tableau(i))
            for (k, offset) in tableauOffsets(column).enumerated() {
                out.append(.init(card: column[k], pile: .tableau(i), index: k,
                                 center: CGPoint(x: base.x, y: base.y + offset), z: 300 + Double(k)))
            }
        }
        return out
    }

    /// Area that accepts a drop onto `pile`: its slot plus any fanned cards.
    func dropRect(_ pile: PileRef, in table: Table) -> CGRect {
        let center = slotCenter(pile)
        var rect = CGRect(x: center.x - cardSize.width / 2, y: center.y - cardSize.height / 2,
                          width: cardSize.width, height: cardSize.height)
        if case .tableau(let i) = pile, let last = tableauOffsets(table.tableau[i]).last {
            rect.size.height += last
        }
        return rect.insetBy(dx: -gap / 2, dy: -gap / 2)
    }

    /// The legal pile that the dragged card overlaps most.
    func dropTarget(cardCenter: CGPoint, from: PileRef, index: Int, game: Klondike) -> PileRef? {
        let dragged = CGRect(x: cardCenter.x - cardSize.width / 2, y: cardCenter.y - cardSize.height / 2,
                             width: cardSize.width, height: cardSize.height)
        return PileRef.dropTargets
            .compactMap { pile -> (PileRef, CGFloat)? in
                let overlap = dropRect(pile, in: game.table).intersection(dragged)
                guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { return nil }
                return (pile, overlap.width * overlap.height)
            }
            .sorted { $0.1 > $1.1 }
            .first { game.canMove(from: from, index: index, to: $0.0) }?
            .0
    }
}
