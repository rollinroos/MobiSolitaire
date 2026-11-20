import SwiftUI

/// A playing card with a 3D finish: lit bevel, visible card thickness,
/// layered shadows and raised pips. Appearance comes from `\.cardStyle` and `\.courtArt`.
struct CardView: View {
    let card: Card
    let size: CGSize
    /// False for cards buried in a pile, so dozens of stacked shadows don't pile up.
    var raised = true
    @Environment(\.cardStyle) private var style

    private var w: CGFloat { size.width }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: w * 0.1, style: .continuous) }

    var body: some View {
        ZStack {
            if card.faceUp {
                CardFace(card: card, size: size, style: style)
            } else {
                CardBack(size: size, style: style)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(bevel)
        .background(shape.fill(style.edge).offset(y: max(1, w * 0.03)))
        .shadow(color: .black.opacity(raised ? 0.25 : 0), radius: max(0.5, w * 0.012), y: w * 0.012)
        .shadow(color: .black.opacity(raised ? 0.16 : 0), radius: w * 0.07, y: w * 0.045)
        .accessibilityElement()
        .accessibilityLabel(card.faceUp ? "\(card.rankLabel) of \(card.suit.rawValue)" : "Face-down card")
    }

    /// Light from the top-left: bright rim up top, shaded rim at the bottom right.
    private var bevel: some View {
        let rim = max(1, w * 0.022)
        return ZStack {
            shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.2), .black.opacity(0.3)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing),
                               lineWidth: rim)
            shape.inset(by: rim).strokeBorder(.white.opacity(0.4), lineWidth: 0.5)
        }
    }
}

// MARK: - Face

private struct CardFace: View {
    let card: Card
    let size: CGSize
    let style: CardStyle

    private var w: CGFloat { size.width }
    private var h: CGFloat { size.height }
    private var ink: Color { style.ink(card.suit) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: style.faceGradient, startPoint: .top, endPoint: .bottom)
            center
            LinearGradient(stops: [.init(color: .white.opacity(style.gloss), location: 0),
                                   .init(color: .white.opacity(0), location: 0.42)],
                           startPoint: .topLeading, endPoint: .bottom)
                .allowsHitTesting(false)
            index
        }
        .drawingGroup()
    }

    private var index: some View {
        HStack(alignment: .center, spacing: w * 0.015) {
            Text(card.rankLabel)
                .font(.system(size: w * 0.28, weight: style.indexWeight, design: style.indexDesign))
                .tracking(card.rank == 10 ? -w * 0.025 : 0)
                .fixedSize()
            SuitGlyph(suit: card.suit, size: w * 0.17)
        }
        .foregroundStyle(ink)
        .padding(.leading, w * 0.08)
        .padding(.top, w * 0.04)
    }

    @ViewBuilder private var center: some View {
        switch card.rank {
        case 1: ace
        case 11...13: CourtPanel(card: card, size: size, style: style)
        default: pips
        }
    }

    private var ace: some View {
        ZStack {
            Circle()
                .strokeBorder(LinearGradient(colors: style.accent, startPoint: .top, endPoint: .bottom),
                              lineWidth: max(1, w * 0.014))
                .frame(width: w * 0.68, height: w * 0.68)
            Circle()
                .strokeBorder(style.accent[0].opacity(0.45), lineWidth: max(0.5, w * 0.006))
                .frame(width: w * 0.6, height: w * 0.6)
            Pip(suit: card.suit, size: w * 0.42, color: ink)
        }
        .position(x: w / 2, y: h * 0.6)
    }

    private var pips: some View {
        let few = card.rank <= 3
        let pipSize = w * (few ? 0.24 : card.rank == 10 ? 0.18 : 0.2)
        let area = CGRect(x: w * 0.28, y: h * (few ? 0.4 : 0.38),
                          width: w * 0.44, height: h * (few ? 0.44 : 0.49))
        return ZStack {
            ForEach(Array(PipLayout.positions(for: card.rank).enumerated()), id: \.offset) { _, pt in
                Pip(suit: card.suit, size: pipSize, color: ink, flipped: pt.y > 0.5)
                    .position(x: area.minX + pt.x * area.width, y: area.minY + pt.y * area.height)
            }
        }
        .frame(width: w, height: h)
    }
}

/// Framed double-ended court figure for J, Q and K.
private struct CourtPanel: View {
    let card: Card
    let size: CGSize
    let style: CardStyle
    @Environment(\.courtArt) private var art

    var body: some View {
        let w = size.width, h = size.height
        // Starts below the corner index so the large rank letter never touches the frame.
        let frame = CGRect(x: w * 0.1, y: h * 0.265, width: w * 0.8, height: h * 0.7)
        let panel = RoundedRectangle(cornerRadius: w * 0.035, style: .continuous)
        ZStack {
            CourtFigure(rank: card.rank, suit: card.suit, art: art, style: style)
                .clipShape(panel)
            panel.strokeBorder(Color(hex: 0x1A1A1A), lineWidth: max(0.75, w * 0.011))
        }
        .frame(width: frame.width, height: frame.height)
        .position(x: frame.midX, y: frame.midY)
    }
}

// MARK: - Back

private struct CardBack: View {
    let size: CGSize
    let style: CardStyle

    var body: some View {
        let w = size.width
        ZStack {
            LinearGradient(colors: style.backGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            BackPattern(style: style, unit: w)
                .padding(w * 0.1)
            RoundedRectangle(cornerRadius: w * 0.06, style: .continuous)
                .strokeBorder(style.backTrim, lineWidth: max(1, w * 0.03))
                .padding(w * 0.07)
            ZStack {
                Circle().fill(LinearGradient(colors: style.backGradient.reversed(), startPoint: .top, endPoint: .bottom))
                Circle().strokeBorder(style.backTrim, lineWidth: max(1, w * 0.022))
                SuitGlyph(suit: .spades, size: w * 0.17)
                    .foregroundStyle(style.backTrim)
            }
            .frame(width: w * 0.36, height: w * 0.36)
            LinearGradient(stops: [.init(color: .white.opacity(style == .glass ? 0.35 : 0.18), location: 0),
                                   .init(color: .white.opacity(0), location: 0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .drawingGroup()
    }
}

private struct BackPattern: View {
    let style: CardStyle
    let unit: CGFloat

    var body: some View {
        Canvas { ctx, size in
            switch style {
            case .classic:
                let step = unit * 0.11
                var path = Path()
                var x = -size.height
                while x < size.width + size.height {
                    path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    path.move(to: CGPoint(x: x + size.height, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                ctx.stroke(path, with: .color(style.backTrim.opacity(0.28)), lineWidth: max(0.5, unit * 0.01))
            case .glass:
                var band = Path()
                band.move(to: CGPoint(x: 0, y: size.height * 0.55))
                band.addLine(to: CGPoint(x: size.width, y: size.height * 0.15))
                band.addLine(to: CGPoint(x: size.width, y: size.height * 0.4))
                band.addLine(to: CGPoint(x: 0, y: size.height * 0.8))
                ctx.fill(band, with: .color(.white.opacity(0.14)))
                let spots: [(CGFloat, CGFloat, CGFloat)] = [(0.2, 0.15, 0.08), (0.75, 0.3, 0.13), (0.3, 0.85, 0.1),
                                                             (0.8, 0.75, 0.08), (0.55, 0.1, 0.13)]
                for (x, y, r) in spots {
                    let radius = unit * r
                    ctx.fill(Path(ellipseIn: CGRect(x: size.width * x - radius, y: size.height * y - radius,
                                                    width: 2 * radius, height: 2 * radius)),
                             with: .color(.white.opacity(0.12)))
                }
            }
        }
    }
}

// MARK: - Shared pieces

struct SuitGlyph: View {
    let suit: Suit
    let size: CGFloat

    var body: some View {
        Image(systemName: "suit.\(name).fill")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }

    private var name: String {
        switch suit {
        case .spades: "spade"
        case .hearts: "heart"
        case .diamonds: "diamond"
        case .clubs: "club"
        }
    }
}

/// A suit symbol with a soft top-lit gradient and a drop edge so it looks printed and raised.
private struct Pip: View {
    let suit: Suit
    let size: CGFloat
    let color: Color
    var flipped = false

    var body: some View {
        SuitGlyph(suit: suit, size: size)
            .foregroundStyle(color.gradient)
            .shadow(color: .black.opacity(0.28), radius: 0, y: size * 0.05)
            .rotationEffect(.degrees(flipped ? 180 : 0))
    }
}

#Preview {
    HStack {
        CardView(card: Card(suit: .hearts, rank: 12, faceUp: true), size: CGSize(width: 100, height: 140))
        CardView(card: Card(suit: .spades, rank: 13, faceUp: true), size: CGSize(width: 100, height: 140))
        CardView(card: Card(suit: .clubs, rank: 11), size: CGSize(width: 100, height: 140))
    }
    .padding()
    .background(.green)
}
