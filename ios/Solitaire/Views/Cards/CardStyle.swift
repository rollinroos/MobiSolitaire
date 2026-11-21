import SwiftUI

/// Visual themes for the deck. Both share the same layout and 3D treatment;
/// they differ in materials, colors, typography and card backs.
enum CardStyle: String, CaseIterable, Identifiable {
    case classic, glass, large

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: "Classic"
        case .glass: "Glass"
        case .large: "Large Print"
        }
    }

    /// Icon for the style toggle in the top bar.
    var symbol: String {
        switch self {
        case .classic: "suit.spade.fill"
        case .glass: "drop.fill"
        case .large: "textformat.size"
        }
    }

    var next: CardStyle {
        switch self {
        case .classic: .glass
        case .glass: .large
        case .large: .classic
        }
    }

    /// How much of each face-up card shows in a tableau column. Large Print shows more
    /// so its oversized rank and suit stay readable when cards overlap.
    var fanRatio: CGFloat { self == .large ? 0.44 : 0.28 }

    // MARK: Face

    var faceGradient: [Color] {
        switch self {
        case .classic: [Color(hex: 0xFFFDF6), Color(hex: 0xF3ECDC)]
        case .glass: [Color(hex: 0xFFFFFF), Color(hex: 0xE4ECF7)]
        case .large: [.white, .white]
        }
    }

    func ink(_ suit: Suit) -> Color {
        switch self {
        case .classic: suit.isRed ? Color(hex: 0xC4122F) : Color(hex: 0x1A1E29)
        case .glass: suit.isRed ? Color(hex: 0xE23B63) : Color(hex: 0x1C2A4D)
        // Strongest contrast on white: pure black and a deep, saturated red.
        case .large: suit.isRed ? Color(hex: 0xC80000) : .black
        }
    }

    var indexDesign: Font.Design { self == .glass ? .rounded : .serif }
    var indexWeight: Font.Weight {
        switch self {
        case .classic: .bold
        case .glass: .semibold
        case .large: .bold
        }
    }

    /// Metallic trim used on face-card frames and the ace ring.
    var accent: [Color] {
        switch self {
        case .classic: [Color(hex: 0xD6B25E), Color(hex: 0x8C6A22)]
        case .glass: [Color(hex: 0x9CC8FF), Color(hex: 0x5B7FD6)]
        case .large: [.black, .black]
        }
    }

    /// Fill inside the J/Q/K frame, tinted by suit color.
    func courtFill(_ suit: Suit) -> [Color] {
        let base = ink(suit)
        return self == .glass ? [base.opacity(0.16), base.opacity(0.04)] : [base.opacity(0.1), base.opacity(0.03)]
    }

    /// The darker card-edge color that shows as the card's thickness.
    var edge: Color {
        switch self {
        case .classic: Color(hex: 0xCFC4AA)
        case .glass: Color(hex: 0xA9B9D3)
        case .large: Color(hex: 0x8A8A8A)
        }
    }

    /// Gloss strength across the top of the face.
    var gloss: Double {
        switch self {
        case .classic: 0.3
        case .glass: 0.75
        case .large: 0 // no sheen, so nothing washes out the ink
        }
    }

    // MARK: Back

    var backGradient: [Color] {
        switch self {
        case .classic: [Color(hex: 0x2A4D8F), Color(hex: 0x14295A)]
        case .glass: [Color(hex: 0x4FA3FF), Color(hex: 0x3B2FBF)]
        case .large: [Color(hex: 0x0A3BA8), Color(hex: 0x0A3BA8)]
        }
    }

    var backTrim: Color { self == .glass ? .white.opacity(0.9) : Color(hex: 0xFFFDF6) }
}

extension EnvironmentValues {
    @Entry var cardStyle: CardStyle = .classic
    @Entry var courtArt: CourtArt = .regal
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}
