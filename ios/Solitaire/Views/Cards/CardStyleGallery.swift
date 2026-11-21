#if DEBUG
import SwiftUI

/// Side-by-side comparison of every face-card art version. Launch with
/// `-CardGallery` to show it; it also writes `face-cards.png` to Documents.
struct CardStyleGallery: View {
    static let width: CGFloat = 920
    var style: CardStyle = .classic
    var arts: [CourtArt] = CourtArt.allCases

    private let showcase: [Card] = [
        Card(suit: .spades, rank: 13, faceUp: true),
        Card(suit: .hearts, rank: 12, faceUp: true),
        Card(suit: .diamonds, rank: 11, faceUp: true),
        Card(suit: .hearts, rank: 13, faceUp: true),
        Card(suit: .clubs, rank: 12, faceUp: true),
        Card(suit: .spades, rank: 11, faceUp: true),
    ]

    private let column: [Card] = [
        Card(suit: .clubs, rank: 3),
        Card(suit: .spades, rank: 6),
        Card(suit: .hearts, rank: 13, faceUp: true),
        Card(suit: .spades, rank: 12, faceUp: true),
        Card(suit: .diamonds, rank: 11, faceUp: true),
        Card(suit: .clubs, rank: 10, faceUp: true),
    ]

    private let loose: [Card] = [
        Card(suit: .clubs, rank: 13, faceUp: true),
        Card(suit: .diamonds, rank: 12, faceUp: true),
        Card(suit: .hearts, rank: 11, faceUp: true),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            ForEach(arts) { art in
                section(number: (CourtArt.allCases.firstIndex(of: art) ?? 0) + 1, art: art)
                    .environment(\.courtArt, art)
            }
        }
        .padding(28)
        .frame(width: Self.width, alignment: .leading)
        .background(FeltBackground())
        .environment(\.cardStyle, style)
        .environment(\.colorScheme, .dark)
    }

    private func section(number: Int, art: CourtArt) -> some View {
        let big = CGSize(width: 112, height: 156.8)
        let small = CGSize(width: 50, height: 70)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(number). \(art.name)").font(.title2.weight(.bold))
                Text(art.tagline).font(.subheadline).foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)

            HStack(alignment: .top, spacing: 12) {
                ForEach(showcase) { CardView(card: $0, size: big) }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Game size")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    HStack(alignment: .top, spacing: 8) {
                        ZStack(alignment: .top) {
                            ForEach(Array(column.enumerated()), id: \.offset) { k, card in
                                CardView(card: card, size: small)
                                    .offset(y: offset(for: k, height: small.height))
                            }
                        }
                        .frame(width: small.width, height: 140, alignment: .top)
                        VStack(spacing: 6) {
                            ForEach(loose) { CardView(card: $0, size: small) }
                        }
                    }
                }
                .padding(.leading, 8)
            }
        }
    }

    private func offset(for index: Int, height: CGFloat) -> CGFloat {
        column.prefix(index).reduce(0) { $0 + ($1.faceUp ? height * 0.28 : height * 0.12) }
    }

    /// Renders one PNG per art version (`face-cards-1.png` …); a single tall image is too big for the simulator GPU.
    @MainActor
    static func renderPNG() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        for (i, art) in CourtArt.allCases.enumerated() {
            let renderer = ImageRenderer(content: CardStyleGallery(arts: [art]))
            renderer.scale = 2
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
            if let data = renderer.uiImage?.pngData() {
                try? data.write(to: docs.appendingPathComponent("face-cards-\(i + 1).png"))
            }
        }
        let backs = ImageRenderer(content: BackGallery())
        backs.scale = 2
        if let data = backs.uiImage?.pngData() {
            try? data.write(to: docs.appendingPathComponent("card-backs.png"))
        }
        let glass = ImageRenderer(content: CardStyleGallery(style: .glass, arts: [.regal]))
        glass.scale = 2
        glass.proposedSize = ProposedViewSize(width: width, height: nil)
        if let data = glass.uiImage?.pngData() {
            try? data.write(to: docs.appendingPathComponent("face-cards-glass.png"))
        }
        let large = ImageRenderer(content: CardStyleGallery(style: .large, arts: [.regal]))
        large.scale = 2
        large.proposedSize = ProposedViewSize(width: width, height: nil)
        if let data = large.uiImage?.pngData() {
            try? data.write(to: docs.appendingPathComponent("face-cards-large.png"))
        }
    }
}

/// Both card backs, large and at game size (stock pile and a tableau column).
private struct BackGallery: View {
    var body: some View {
        HStack(alignment: .top, spacing: 48) {
            ForEach(CardStyle.allCases) { style in
                VStack(alignment: .leading, spacing: 14) {
                    Text(style.name).font(.title2.weight(.bold)).foregroundStyle(.white)
                    HStack(alignment: .top, spacing: 18) {
                        CardView(card: Card(suit: .spades, rank: 1), size: CGSize(width: 160, height: 224))
                        VStack(alignment: .leading, spacing: 10) {
                            CardView(card: Card(suit: .hearts, rank: 2), size: CGSize(width: 50, height: 70))
                            ZStack(alignment: .top) {
                                ForEach(0..<4) { k in
                                    CardView(card: Card(suit: .clubs, rank: 3 + k, faceUp: k == 3),
                                             size: CGSize(width: 50, height: 70))
                                        .offset(y: CGFloat(k) * 8.4)
                                }
                            }
                        }
                    }
                }
                .environment(\.cardStyle, style)
            }
        }
        .padding(28)
        .background(FeltBackground())
    }
}

#Preview {
    ScrollView([.horizontal, .vertical]) { CardStyleGallery() }
}
#endif
