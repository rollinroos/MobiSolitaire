import Foundation

enum Suit: String, CaseIterable, Codable, Sendable {
    case spades, hearts, diamonds, clubs

    var symbol: String {
        switch self {
        case .spades: "♠"
        case .hearts: "♥"
        case .diamonds: "♦"
        case .clubs: "♣"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }
}

struct Card: Identifiable, Hashable, Codable, Sendable {
    let suit: Suit
    let rank: Int
    var faceUp = false

    var id: String { "\(suit.rawValue)-\(rank)" }

    var rankLabel: String {
        switch rank {
        case 1: "A"
        case 11: "J"
        case 12: "Q"
        case 13: "K"
        default: String(rank)
        }
    }

    /// True when this card may be placed on `other` in the tableau.
    func stacks(on other: Card) -> Bool {
        other.rank == rank + 1 && other.suit.isRed != suit.isRed
    }
}

enum PileRef: Hashable, Codable, Sendable {
    case stock
    case waste
    case foundation(Int)
    case tableau(Int)

    static let dropTargets: [PileRef] = (0..<4).map(PileRef.foundation) + (0..<7).map(PileRef.tableau)
}
