import SwiftUI

struct CardView: View {
    let card: Card
    let size: CGSize

    private var radius: CGFloat { size.width * 0.12 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }

    var body: some View {
        ZStack {
            if card.faceUp { face } else { back }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.28), radius: 1.5, y: 1)
        .accessibilityElement()
        .accessibilityLabel(card.faceUp ? "\(card.rankLabel) of \(card.suit.rawValue)" : "Face-down card")
    }

    private var ink: Color {
        card.suit.isRed ? Color(red: 0.80, green: 0.16, blue: 0.20) : Color(red: 0.11, green: 0.13, blue: 0.19)
    }

    private var face: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(white: 1.0), Color(red: 0.96, green: 0.95, blue: 0.92)],
                           startPoint: .top, endPoint: .bottom)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(card.rankLabel)
                    .font(.system(size: size.width * 0.3, weight: .bold, design: .rounded))
                    .tracking(card.rank == 10 ? -1 : 0)
                Text(card.suit.symbol)
                    .font(.system(size: size.width * 0.24))
            }
            .padding(.leading, size.width * 0.07)
            .padding(.top, size.width * 0.03)

            Text(card.suit.symbol)
                .font(.system(size: size.width * 0.52))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(y: size.height * 0.1)
        }
        .foregroundStyle(ink)
    }

    private var back: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.20, green: 0.33, blue: 0.62), Color(red: 0.12, green: 0.19, blue: 0.42)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RoundedRectangle(cornerRadius: radius * 0.6, style: .continuous)
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                .padding(size.width * 0.08)
            Image(systemName: "suit.spade.fill")
                .font(.system(size: size.width * 0.28))
                .foregroundStyle(.white.opacity(0.22))
        }
    }
}

#Preview {
    HStack {
        CardView(card: Card(suit: .hearts, rank: 10, faceUp: true), size: CGSize(width: 70, height: 98))
        CardView(card: Card(suit: .spades, rank: 1, faceUp: true), size: CGSize(width: 70, height: 98))
        CardView(card: Card(suit: .clubs, rank: 12), size: CGSize(width: 70, height: 98))
    }
    .padding()
    .background(.green)
}
