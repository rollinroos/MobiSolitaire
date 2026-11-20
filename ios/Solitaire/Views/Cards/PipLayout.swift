import CoreGraphics

/// Traditional pip arrangements for number cards.
/// Points are normalized: x is 0 (left), 0.5 (center) or 1 (right) column,
/// y runs 0 (top row) to 1 (bottom row). Pips below the middle are drawn upside down.
enum PipLayout {
    static func positions(for rank: Int) -> [CGPoint] {
        let l: CGFloat = 0, c: CGFloat = 0.5, r: CGFloat = 1
        let corners = [p(l, 0), p(r, 0), p(l, 1), p(r, 1)]
        let sixes = corners + [p(l, 0.5), p(r, 0.5)]
        let tall = [p(l, 0), p(r, 0), p(l, 1 / 3), p(r, 1 / 3), p(l, 2 / 3), p(r, 2 / 3), p(l, 1), p(r, 1)]
        switch rank {
        case 2: return [p(c, 0), p(c, 1)]
        case 3: return [p(c, 0), p(c, 0.5), p(c, 1)]
        case 4: return corners
        case 5: return corners + [p(c, 0.5)]
        case 6: return sixes
        case 7: return sixes + [p(c, 0.25)]
        case 8: return sixes + [p(c, 0.25), p(c, 0.75)]
        case 9: return tall + [p(c, 0.5)]
        case 10: return tall + [p(c, 1 / 6), p(c, 5 / 6)]
        default: return []
        }
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}
