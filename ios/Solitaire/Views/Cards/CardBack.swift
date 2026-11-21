import SwiftUI
import UIKit

/// Card back in a traditional ornate style: white border, fine lattice field,
/// corner rosettes and a central medallion with all four suits. The design has
/// the same 180° symmetry as the face cards. Each style/size is drawn once and
/// cached as an image, since a game shows dozens of backs at a time.
struct CardBack: View {
    let size: CGSize
    let style: CardStyle

    var body: some View {
        Image(uiImage: CardBackCache.image(style: style, size: size))
            .resizable()
            .interpolation(.high)
    }
}

@MainActor
private enum CardBackCache {
    private static var images: [String: UIImage] = [:]

    static func image(style: CardStyle, size: CGSize) -> UIImage {
        let key = "\(style.rawValue)-\(Int(size.width.rounded()))"
        if let cached = images[key] { return cached }
        let renderer = ImageRenderer(content: CardBackArtwork(style: style).frame(width: size.width, height: size.height))
        renderer.scale = UITraitCollection.current.displayScale > 0 ? UITraitCollection.current.displayScale : 3
        let image = renderer.uiImage ?? UIImage()
        images[key] = image
        return image
    }
}

/// The drawing itself, on a 100 × 140 unit canvas.
private struct CardBackArtwork: View {
    let style: CardStyle

    private struct Colors {
        var border: Color
        var field: [Color]
        var medallion: [Color]
        var line: Color
        var petal: [Color]
        var heart: [Color]
        var gloss: Double
    }

    private var colors: Colors {
        switch style {
        case .classic:
            Colors(border: Color(hex: 0xFFFDF6),
                   field: [Color(hex: 0x2A4D8F), Color(hex: 0x14295A)],
                   medallion: [Color(hex: 0x1B3266), Color(hex: 0x0F1F45)],
                   line: Color(hex: 0xF4EEDD),
                   petal: [Color(hex: 0xE0384F), Color(hex: 0xA30F27)],
                   heart: [Color(hex: 0xF7D774), Color(hex: 0xC99A2E)],
                   gloss: 0.14)
        case .glass:
            Colors(border: Color(hex: 0xF4F8FF),
                   field: [Color(hex: 0x4FA3FF), Color(hex: 0x3B2FBF)],
                   medallion: [Color(hex: 0x3D6FF0), Color(hex: 0x3424A8)],
                   line: .white,
                   petal: [Color(hex: 0xFF8FB0), Color(hex: 0xE23B63)],
                   heart: [Color(hex: 0xFFFFFF), Color(hex: 0xC9DCFF)],
                   gloss: 0.38)
        case .large:
            // Bold, flat blue so face-down cards are unmistakable next to white faces.
            Colors(border: .white,
                   field: [Color(hex: 0x0A3BA8), Color(hex: 0x0A3BA8)],
                   medallion: [Color(hex: 0x062A7A), Color(hex: 0x062A7A)],
                   line: .white,
                   petal: [Color(hex: 0xFFD60A), Color(hex: 0xFFB800)],
                   heart: [.white, .white],
                   gloss: 0)
        }
    }

    var body: some View {
        Canvas { ctx, size in
            draw(&ctx, size)
        } symbols: {
            ForEach(Array(Suit.allCases.enumerated()), id: \.offset) { i, suit in
                SuitGlyph(suit: suit, size: 9)
                    .foregroundStyle(colors.line)
                    .tag(i)
            }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let c = colors
        ctx.scaleBy(x: size.width / 100, y: size.height / 140)
        let all = CGRect(x: 0, y: 0, width: 100, height: 140)
        ctx.fill(Path(all), with: .color(c.border))

        // Field.
        let fieldRect = all.insetBy(dx: 6, dy: 6)
        let field = Path(roundedRect: fieldRect, cornerRadius: 4)
        ctx.fill(field, with: .linearGradient(Gradient(colors: c.field), startPoint: .zero, endPoint: CGPoint(x: 100, y: 140)))

        // Lattice with small quatrefoils at the crossings.
        do {
            var lattice = ctx
            lattice.clip(to: Path(roundedRect: fieldRect.insetBy(dx: 3.6, dy: 3.6), cornerRadius: 2.5))
            let step: CGFloat = 7
            var lines = Path()
            var x: CGFloat = -140
            while x < 240 {
                lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x + 140, y: 140))
                lines.move(to: CGPoint(x: x + 140, y: 0)); lines.addLine(to: CGPoint(x: x, y: 140))
                x += step
            }
            lattice.stroke(lines, with: .color(c.line.opacity(0.3)), lineWidth: 0.45)
            var dots = Path()
            var diamonds = Path()
            var row = 0
            var y: CGFloat = 70.0.truncatingRemainder(dividingBy: step / 2) // keep the grid centered
            while y < 140 {
                var x0: CGFloat = 50.0.truncatingRemainder(dividingBy: step) + (row % 2 == 0 ? 0 : step / 2)
                while x0 < 100 {
                    if row % 2 == 0 {
                        for (dx, dy) in [(0.0, -0.9), (0.9, 0.0), (0.0, 0.9), (-0.9, 0.0)] {
                            dots.addEllipse(in: CGRect(x: x0 + dx - 0.7, y: y + dy - 0.7, width: 1.4, height: 1.4))
                        }
                    } else {
                        diamonds.move(to: CGPoint(x: x0, y: y - 0.9)); diamonds.addLine(to: CGPoint(x: x0 + 0.9, y: y))
                        diamonds.addLine(to: CGPoint(x: x0, y: y + 0.9)); diamonds.addLine(to: CGPoint(x: x0 - 0.9, y: y))
                        diamonds.closeSubpath()
                    }
                    x0 += step
                }
                y += step / 2; row += 1
            }
            lattice.fill(dots, with: .color(c.line.opacity(0.55)))
            lattice.fill(diamonds, with: .color(c.line.opacity(0.35)))
        }

        // Double frame.
        ctx.stroke(Path(roundedRect: fieldRect.insetBy(dx: 2, dy: 2), cornerRadius: 3), with: .color(c.line), lineWidth: 0.9)
        ctx.stroke(Path(roundedRect: fieldRect.insetBy(dx: 3.5, dy: 3.5), cornerRadius: 2.4),
                   with: .color(c.line.opacity(0.7)), lineWidth: 0.35)

        // Corner rosettes.
        for (x, y) in [(15.0, 15.0), (85.0, 15.0), (15.0, 125.0), (85.0, 125.0)] {
            rosette(&ctx, center: CGPoint(x: x, y: y), radius: 4.2, petals: 8, c)
        }

        // Central medallion.
        let medallion = Path(ellipseIn: CGRect(x: 25, y: 38, width: 50, height: 64))
        ctx.fill(medallion, with: .radialGradient(Gradient(colors: c.medallion), center: CGPoint(x: 50, y: 62),
                                                  startRadius: 2, endRadius: 40))
        ctx.stroke(medallion, with: .color(c.line), lineWidth: 1)
        ctx.stroke(Path(ellipseIn: CGRect(x: 27.5, y: 40.5, width: 45, height: 59)), with: .color(c.line.opacity(0.7)), lineWidth: 0.35)
        // Bead ring.
        var beads = Path()
        for k in 0..<36 {
            let a = Double(k) / 36 * 2 * .pi
            beads.addEllipse(in: CGRect(x: 50 + cos(a) * 20.5 - 0.45, y: 70 + sin(a) * 26.5 - 0.45, width: 0.9, height: 0.9))
        }
        ctx.fill(beads, with: .color(c.line.opacity(0.8)))

        rosette(&ctx, center: CGPoint(x: 50, y: 70), radius: 11, petals: 8, c)

        // Suits around the rosette; the lower pair is turned so the back reads the same both ways.
        let spots: [(Int, CGFloat, CGFloat, Double)] = [(0, 50, 50, 0), (1, 65, 70, 0), (2, 50, 90, 180), (3, 35, 70, 180)]
        for (id, x, y, angle) in spots {
            guard let symbol = ctx.resolveSymbol(id: id) else { continue }
            var s = ctx
            s.translateBy(x: x, y: y)
            s.rotate(by: .degrees(angle))
            s.draw(symbol, at: .zero)
        }

        // Light across the top.
        if c.gloss > 0 {
            var gloss = Path()
            gloss.move(to: .zero); gloss.addLine(to: CGPoint(x: 100, y: 0)); gloss.addLine(to: CGPoint(x: 100, y: 30))
            gloss.addQuadCurve(to: CGPoint(x: 0, y: 80), control: CGPoint(x: 45, y: 40)); gloss.closeSubpath()
            ctx.fill(gloss, with: .linearGradient(Gradient(colors: [.white.opacity(c.gloss), .white.opacity(0)]),
                                                  startPoint: CGPoint(x: 10, y: 0), endPoint: CGPoint(x: 50, y: 70)))
        }
    }

    private func rosette(_ ctx: inout GraphicsContext, center: CGPoint, radius r: CGFloat, petals: Int, _ c: Colors) {
        var petalPath = Path()
        for k in 0..<petals {
            let a = Double(k) / Double(petals) * 2 * .pi
            let petal = Path(ellipseIn: CGRect(x: -r * 0.22, y: -r, width: r * 0.44, height: r * 0.8))
            petalPath.addPath(petal, transform: CGAffineTransform(rotationAngle: a).concatenating(
                CGAffineTransform(translationX: center.x, y: center.y)))
        }
        ctx.fill(petalPath, with: .linearGradient(Gradient(colors: c.petal),
                                                  startPoint: CGPoint(x: center.x, y: center.y - r),
                                                  endPoint: CGPoint(x: center.x, y: center.y + r)))
        ctx.stroke(petalPath, with: .color(c.line), lineWidth: max(0.3, r * 0.04))
        let heart = Path(ellipseIn: CGRect(x: center.x - r * 0.3, y: center.y - r * 0.3, width: r * 0.6, height: r * 0.6))
        ctx.fill(heart, with: .linearGradient(Gradient(colors: c.heart),
                                              startPoint: CGPoint(x: center.x, y: center.y - r * 0.3),
                                              endPoint: CGPoint(x: center.x, y: center.y + r * 0.3)))
        ctx.stroke(heart, with: .color(c.line), lineWidth: max(0.3, r * 0.04))
    }
}
