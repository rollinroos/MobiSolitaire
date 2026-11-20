import SwiftUI

/// Variations of the traditional double-ended J, Q and K figures. All use the
/// classic red / yellow / blue / black palette; they differ in proportions,
/// robe patterns and ornament.
enum CourtArt: String, CaseIterable, Identifiable {
    case classic, regal, slender, heraldic, ornate

    var id: String { rawValue }

    var name: String {
        switch self {
        case .classic: "Classic"
        case .regal: "Regal"
        case .slender: "Slender"
        case .heraldic: "Heraldic"
        case .ornate: "Ornate"
        }
    }

    var tagline: String {
        switch self {
        case .classic: "Broad robes with diamond, chevron and stripe panels"
        case .regal: "Larger faces and crowns, checkered robes"
        case .slender: "Narrower figures with more white space, items in full view"
        case .heraldic: "Suit emblem on the chest, solid robes with gold bands"
        case .ornate: "Gold trim on every panel, ermine on all three ranks"
        }
    }

    fileprivate var design: CourtDesign {
        switch self {
        case .classic:
            CourtDesign(bodyWidth: 1, headScale: 1, robe: .diamonds, center: .chevrons, sleeves: .stripes,
                        emblem: false, trim: false, ermineAll: false)
        case .regal:
            CourtDesign(bodyWidth: 1, headScale: 1.18, robe: .checks, center: .quatrefoil, sleeves: .chevrons,
                        emblem: false, trim: false, ermineAll: false)
        case .slender:
            CourtDesign(bodyWidth: 0.8, headScale: 1.08, robe: .diamonds, center: .chevrons, sleeves: .stripes,
                        emblem: false, trim: false, ermineAll: false)
        case .heraldic:
            CourtDesign(bodyWidth: 0.92, headScale: 1.05, robe: .none, center: .none, sleeves: .stripes,
                        emblem: true, trim: true, ermineAll: false)
        case .ornate:
            CourtDesign(bodyWidth: 1, headScale: 1, robe: .diamonds, center: .chevrons, sleeves: .checks,
                        emblem: false, trim: true, ermineAll: true)
        }
    }
}

private enum Pattern { case none, stripes, diamonds, chevrons, dots, checks, quatrefoil, ermine }

private struct CourtDesign {
    var bodyWidth: CGFloat
    var headScale: CGFloat
    var robe: Pattern
    var center: Pattern
    var sleeves: Pattern
    var emblem: Bool
    var trim: Bool
    var ermineAll: Bool
}

/// A traditional half-length court figure with rotational symmetry: the robe is
/// one continuous shape through the middle, and the head, hands and held items
/// repeat upside down. Drawn on a 100 × 126 unit canvas.
struct CourtFigure: View {
    let rank: Int
    let suit: Suit
    let art: CourtArt
    let style: CardStyle

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let pipLeft = rank == 13 // the king's sword is on the right; the others hold things on the left
            ZStack {
                Canvas { ctx, size in
                    render(in: &ctx, size: size)
                } symbols: {
                    SuitGlyph(suit: suit, size: 12)
                        .foregroundStyle(style.ink(suit))
                        .tag(0)
                }
                SuitGlyph(suit: suit, size: w * 0.17)
                    .foregroundStyle(style.ink(suit).gradient)
                    .position(x: w * (pipLeft ? 0.14 : 0.86), y: h * 0.11)
                SuitGlyph(suit: suit, size: w * 0.17)
                    .foregroundStyle(style.ink(suit).gradient)
                    .rotationEffect(.degrees(180))
                    .position(x: w * (pipLeft ? 0.86 : 0.14), y: h * 0.89)
            }
        }
    }

    // MARK: Palette

    private struct Palette {
        let red = GraphicsContext.Shading.color(Color(hex: 0xC8102E))
        let yellow = GraphicsContext.Shading.color(Color(hex: 0xF2C230))
        let blue = GraphicsContext.Shading.color(Color(hex: 0x2756A8))
        let ink = GraphicsContext.Shading.color(Color(hex: 0x111111))
        let white = GraphicsContext.Shading.color(.white)
        let skin = GraphicsContext.Shading.color(Color(hex: 0xF7DCC4))
        let hair = GraphicsContext.Shading.color(Color(hex: 0xF2C230))
        let steel = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Color(hex: 0xEEF1F5), Color(hex: 0x9AA3AE)]),
            startPoint: CGPoint(x: 76, y: 0), endPoint: CGPoint(x: 84, y: 0))
        let outline = GraphicsContext.Shading.color(Color(hex: 0x111111))
        let lineWidth: CGFloat = 0.7
    }

    private let p = Palette()
    private var d: CourtDesign { art.design }

    // MARK: Rendering

    private func render(in ctx: inout GraphicsContext, size: CGSize) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
        ctx.scaleBy(x: size.width / 100, y: size.height / 126)
        let emblem = ctx.resolveSymbol(id: 0)

        // Context copies share the destination but keep their own transform,
        // so no offscreen layers are created.
        func half(_ flipped: Bool) -> GraphicsContext {
            var c = ctx
            if flipped {
                c.translateBy(x: 100, y: 126)
                c.rotate(by: .degrees(180))
            }
            return c
        }
        func widened(_ c: GraphicsContext) -> GraphicsContext {
            var c = c
            c.translateBy(x: 50, y: 0)
            c.scaleBy(x: d.bodyWidth, y: 1)
            c.translateBy(x: -50, y: 0)
            return c
        }

        // 1. Items held behind the body, top and bottom.
        for flipped in [false, true] {
            var c = half(flipped)
            drawBackItems(&c)
        }
        // 2. One continuous robe through the middle.
        var body = widened(ctx)
        drawRobe(&body)
        if d.emblem, let emblem {
            for flipped in [false, true] {
                let c = half(flipped)
                c.draw(emblem, at: P(50, 52))
            }
        }
        // 3. Collars, heads, hands — top and bottom.
        for flipped in [false, true] {
            let c = half(flipped)
            var collarCtx = widened(c)
            drawCollar(&collarCtx)
            var head = c
            head.translateBy(x: 50, y: 4)
            head.scaleBy(x: d.headScale, y: d.headScale)
            head.translateBy(x: -50, y: -4)
            drawHead(&head)
            var front = c
            drawHands(&front)
        }
    }

    private func drawBackItems(_ ctx: inout GraphicsContext) {
        switch rank {
        case 13:
            fill(&ctx, poly([(78.6, 3), (80, 0), (81.4, 3), (81.6, 52), (78.4, 52)]), p.steel)
            fill(&ctx, Path(roundedRect: CGRect(x: 74, y: 51.5, width: 12, height: 2.6), cornerRadius: 1), p.yellow)
            fill(&ctx, Path(CGRect(x: 79, y: 54, width: 2, height: 8)), p.ink)
        case 12:
            // Veil, scaled with the head so it stays framed around the face.
            var veilCtx = ctx
            veilCtx.translateBy(x: 50, y: 4)
            veilCtx.scaleBy(x: d.headScale, y: d.headScale)
            veilCtx.translateBy(x: -50, y: -4)
            var veil = Path()
            veil.move(to: P(38, 12)); veil.addQuadCurve(to: P(30, 44), control: P(29, 26))
            veil.addLine(to: P(70, 44)); veil.addQuadCurve(to: P(62, 12), control: P(71, 26)); veil.closeSubpath()
            fill(&veilCtx, veil, p.white, pattern: .dots, ink: p.blue)
        default:
            fill(&ctx, Path(CGRect(x: 17, y: 6, width: 2.2, height: 52)), p.yellow)
            var head = Path()
            head.move(to: P(18, 0)); head.addQuadCurve(to: P(25, 8), control: P(25.5, 1.5))
            head.addQuadCurve(to: P(18, 13), control: P(23, 12.5)); head.addQuadCurve(to: P(11, 8), control: P(13, 12.5))
            head.addQuadCurve(to: P(18, 0), control: P(10.5, 1.5)); head.closeSubpath()
            fill(&ctx, head, p.steel)
            gem(&ctx, 18.1, 7.5, 1.3, p.red)
        }
    }

    /// The robe is symmetric under a 180° turn, so it reads continuously through the center.
    private func drawRobe(_ ctx: inout GraphicsContext) {
        var robe = Path()
        robe.move(to: P(32, 41)); robe.addLine(to: P(68, 41))
        robe.addQuadCurve(to: P(90, 52), control: P(86, 43)); robe.addLine(to: P(90, 74))
        robe.addQuadCurve(to: P(68, 85), control: P(86, 83)); robe.addLine(to: P(32, 85))
        robe.addQuadCurve(to: P(10, 74), control: P(14, 83)); robe.addLine(to: P(10, 52))
        robe.addQuadCurve(to: P(32, 41), control: P(14, 43)); robe.closeSubpath()
        fill(&ctx, robe, p.red, pattern: d.robe, ink: p.yellow, stroke: false)

        var inner = ctx
        inner.clip(to: robe)
        let left = poly([(6, 51), (19, 44.5), (26.5, 63), (19, 81.5), (6, 75)])
        let right = poly([(94, 75), (81, 81.5), (73.5, 63), (81, 44.5), (94, 51)])
        fill(&inner, left, p.blue, pattern: d.sleeves, ink: p.white, trim: d.trim)
        fill(&inner, right, p.blue, pattern: d.sleeves, ink: p.white, trim: d.trim)
        let center = poly([(39, 41), (61, 41), (64, 63), (61, 85), (39, 85), (36, 63)])
        fill(&inner, center, p.yellow, pattern: d.center, ink: p.ink, trim: d.trim)
        if rank == 13 || d.ermineAll {
            fill(&inner, poly([(35, 41), (39, 41), (36, 63), (39, 85), (35, 85), (32, 63)]), p.white, pattern: .ermine, ink: p.ink)
            fill(&inner, poly([(65, 85), (61, 85), (64, 63), (61, 41), (65, 41), (68, 63)]), p.white, pattern: .ermine, ink: p.ink)
        }
        ctx.stroke(robe, with: p.outline, style: StrokeStyle(lineWidth: p.lineWidth, lineJoin: .round))
    }

    private func drawCollar(_ ctx: inout GraphicsContext) {
        var collar = Path()
        collar.move(to: P(29, 41)); collar.addQuadCurve(to: P(50, 49), control: P(39, 49))
        collar.addQuadCurve(to: P(71, 41), control: P(61, 49)); collar.addLine(to: P(66, 36.5))
        collar.addQuadCurve(to: P(50, 42), control: P(58, 42.5)); collar.addQuadCurve(to: P(34, 36.5), control: P(42, 42.5))
        collar.closeSubpath()
        switch rank {
        case 13: fill(&ctx, collar, p.yellow, pattern: .dots, ink: p.red)
        case 12: fill(&ctx, collar, p.white, pattern: .dots, ink: p.blue)
        default: fill(&ctx, collar, p.red, pattern: .dots, ink: p.yellow)
        }
        if d.trim {
            for x in [40.0, 50.0, 60.0] { gem(&ctx, x, x == 50 ? 46.5 : 44.6, 1, x == 50 ? p.blue : p.red) }
        }
    }

    private func drawHead(_ ctx: inout GraphicsContext) {
        switch rank {
        case 13:
            fill(&ctx, poly([(41, 17), (37, 37), (43, 37), (43, 20)]), p.hair)
            fill(&ctx, poly([(59, 17), (63, 37), (57, 37), (57, 20)]), p.hair)
        case 11:
            for (x, y, r) in [(39.5, 31.0, 4.2), (60.5, 31.0, 4.2), (40.5, 24.0, 3.6), (59.5, 24.0, 3.6)] {
                fill(&ctx, Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), p.hair)
            }
        default: break
        }
        fill(&ctx, Path(CGRect(x: 46, y: 31, width: 8, height: 7)), p.skin)
        fill(&ctx, Path(ellipseIn: CGRect(x: 41.5, y: 14, width: 17, height: 21.5)), p.skin)

        if rank != 13 {
            var fringe = Path()
            fringe.move(to: P(41.6, 25)); fringe.addQuadCurve(to: P(50, 14.5), control: P(41, 14.5))
            fringe.addQuadCurve(to: P(58.4, 25), control: P(59, 14.5)); fringe.addQuadCurve(to: P(50, 19), control: P(56, 18))
            fringe.addQuadCurve(to: P(41.6, 25), control: P(44, 18)); fringe.closeSubpath()
            fill(&ctx, fringe, p.hair)
        } else {
            var beard = Path()
            beard.move(to: P(42, 27)); beard.addQuadCurve(to: P(50, 45), control: P(41, 42))
            beard.addQuadCurve(to: P(58, 27), control: P(59, 42)); beard.addQuadCurve(to: P(50, 33.6), control: P(57, 33.6))
            beard.addQuadCurve(to: P(42, 27), control: P(43, 33.6)); beard.closeSubpath()
            fill(&ctx, beard, p.hair)
            var strands = Path()
            for x in [46.0, 50.0, 54.0] {
                strands.move(to: P(x, 35)); strands.addQuadCurve(to: P(50 + (x - 50) * 0.4, 42), control: P(x, 39))
            }
            ctx.stroke(strands, with: p.outline, lineWidth: p.lineWidth * 0.6)
            var stache = Path()
            stache.move(to: P(50, 30.4)); stache.addQuadCurve(to: P(43.5, 31.8), control: P(45.5, 28.8))
            stache.addQuadCurve(to: P(50, 31.6), control: P(47, 32.8)); stache.addQuadCurve(to: P(56.5, 31.8), control: P(53, 32.8))
            stache.addQuadCurve(to: P(50, 30.4), control: P(54.5, 28.8)); stache.closeSubpath()
            fill(&ctx, stache, p.hair)
        }

        // Face.
        let lw: CGFloat = 0.5
        for x in [44.4, 51.8] {
            let eye = Path(ellipseIn: CGRect(x: x, y: 22.4, width: 3.8, height: 2.1))
            ctx.fill(eye, with: p.white)
            ctx.stroke(eye, with: p.outline, lineWidth: lw * 0.8)
            ctx.fill(Path(ellipseIn: CGRect(x: x + 1.2, y: 22.6, width: 1.7, height: 1.7)), with: p.outline)
        }
        var lines = Path()
        lines.move(to: P(44, 21)); lines.addQuadCurve(to: P(48.4, 20.6), control: P(46, 19.6))
        lines.move(to: P(51.6, 20.6)); lines.addQuadCurve(to: P(56, 21), control: P(54, 19.6))
        lines.move(to: P(50.2, 23.4)); lines.addLine(to: P(48.8, 28.6)); lines.addLine(to: P(50.8, 28.9))
        ctx.stroke(lines, with: p.outline, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        if rank != 13 {
            ctx.fill(Path(ellipseIn: CGRect(x: 48.2, y: 31, width: 3.6, height: 1.7)), with: p.red)
        }

        // Headwear.
        switch rank {
        case 13:
            var cap = Path()
            cap.move(to: P(40, 11.5)); cap.addQuadCurve(to: P(60, 11.5), control: P(50, -1)); cap.closeSubpath()
            fill(&ctx, cap, p.red)
            fill(&ctx, poly([(39, 11), (39, 4.5), (42.5, 8.5), (46, 2.5), (50, 8), (54, 2.5), (57.5, 8.5), (61, 4.5), (61, 11)]), p.yellow)
            fill(&ctx, Path(CGRect(x: 39, y: 11, width: 22, height: 4)), p.yellow)
            gem(&ctx, 50, 13, 1.2, p.blue); gem(&ctx, 43.5, 13, 0.9, p.red); gem(&ctx, 56.5, 13, 0.9, p.red)
            for (x, y) in [(46.0, 2.5), (54.0, 2.5), (39.0, 4.5), (61.0, 4.5)] { gem(&ctx, x, y, 0.9, p.white) }
        case 12:
            fill(&ctx, poly([(41, 11.5), (41, 6.5), (45, 9.2), (50, 3.5), (55, 9.2), (59, 6.5), (59, 11.5)]), p.yellow)
            fill(&ctx, Path(CGRect(x: 41, y: 11.5, width: 18, height: 3.4)), p.yellow)
            gem(&ctx, 50, 13.2, 1.1, p.blue); gem(&ctx, 50, 3.6, 1.1, p.white)
            gem(&ctx, 44.5, 13.2, 0.8, p.red); gem(&ctx, 55.5, 13.2, 0.8, p.red)
        default:
            fill(&ctx, Path(ellipseIn: CGRect(x: 32, y: 10, width: 36, height: 6.5)), p.red, pattern: .dots, ink: p.yellow)
            var crown = Path()
            crown.move(to: P(39, 12)); crown.addLine(to: P(41, 2.5)); crown.addQuadCurve(to: P(59, 2.5), control: P(50, 0))
            crown.addLine(to: P(61, 12)); crown.closeSubpath()
            fill(&ctx, crown, p.blue)
            fill(&ctx, Path(CGRect(x: 39.6, y: 8.6, width: 20.8, height: 2.6)), p.yellow)
        }
    }

    private func drawHands(_ ctx: inout GraphicsContext) {
        let edge = { (x: CGFloat) in 50 + (x - 50) * d.bodyWidth }
        switch rank {
        case 13:
            hand(&ctx, 80, 57)
        case 12:
            var stem = Path()
            stem.move(to: P(edge(25), 58)); stem.addQuadCurve(to: P(edge(25) - 4, 35), control: P(edge(25) - 6.5, 47))
            ctx.stroke(stem, with: p.outline, lineWidth: 0.8)
            let fx = edge(25) - 4
            for k in 0..<5 {
                let a = Double(k) / 5 * 2 * .pi - .pi / 2
                let cx = fx + cos(a) * 2.6, cy = 32 + sin(a) * 2.6
                fill(&ctx, Path(ellipseIn: CGRect(x: cx - 2, y: cy - 2, width: 4, height: 4)), p.red)
            }
            gem(&ctx, fx, 32, 1.4, p.yellow)
            hand(&ctx, edge(25), 57)
        default:
            hand(&ctx, 18.1, 55)
        }
    }

    private func hand(_ ctx: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat) {
        fill(&ctx, Path(roundedRect: CGRect(x: x - 4, y: y - 4.2, width: 8, height: 2.2), cornerRadius: 1), p.yellow)
        fill(&ctx, Path(ellipseIn: CGRect(x: x - 3.4, y: y - 2.4, width: 6.8, height: 5.2)), p.skin)
    }

    // MARK: Helpers

    private func fill(_ ctx: inout GraphicsContext, _ path: Path, _ shading: GraphicsContext.Shading,
                      pattern: Pattern = .none, ink: GraphicsContext.Shading? = nil,
                      trim: Bool = false, stroke: Bool = true) {
        ctx.fill(path, with: shading)
        if pattern != .none {
            var layer = ctx
            layer.clip(to: path)
            drawPattern(&layer, pattern, ink ?? p.ink, in: path.boundingRect)
        }
        if trim {
            ctx.stroke(path, with: p.yellow, style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))
        }
        if stroke {
            ctx.stroke(path, with: p.outline, style: StrokeStyle(lineWidth: p.lineWidth, lineJoin: .round))
        }
    }

    private func drawPattern(_ ctx: inout GraphicsContext, _ pattern: Pattern, _ ink: GraphicsContext.Shading, in b: CGRect) {
        var path = Path()
        switch pattern {
        case .stripes:
            var x = b.minX - b.height
            while x < b.maxX {
                path.move(to: P(x, b.maxY)); path.addLine(to: P(x + b.height, b.minY))
                x += 3.4
            }
            ctx.stroke(path, with: ink, lineWidth: 0.8)
        case .diamonds:
            grid(b, step: 5, rowStep: 3.5) { x, y in
                path.move(to: P(x, y - 1.1)); path.addLine(to: P(x + 1.1, y))
                path.addLine(to: P(x, y + 1.1)); path.addLine(to: P(x - 1.1, y)); path.closeSubpath()
            }
            ctx.fill(path, with: ink)
        case .chevrons:
            var y = b.minY + 2
            while y < b.maxY {
                var x = b.minX
                path.move(to: P(x, y))
                var up = true
                while x < b.maxX {
                    x += 2.4
                    path.addLine(to: P(x, up ? y - 1.6 : y))
                    up.toggle()
                }
                y += 3.6
            }
            ctx.stroke(path, with: ink, lineWidth: 0.6)
        case .dots:
            grid(b, step: 3, rowStep: 2.6) { x, y in
                path.addEllipse(in: CGRect(x: x - 0.65, y: y - 0.65, width: 1.3, height: 1.3))
            }
            ctx.fill(path, with: ink)
        case .checks:
            var y = b.minY
            var row = 0
            while y < b.maxY {
                var x = b.minX + (row % 2 == 0 ? 0 : 3)
                while x < b.maxX {
                    path.addRect(CGRect(x: x, y: y, width: 3, height: 3))
                    x += 6
                }
                y += 3; row += 1
            }
            var faded = ctx
            faded.opacity = 0.55
            faded.fill(path, with: ink)
        case .quatrefoil:
            grid(b, step: 6, rowStep: 5) { x, y in
                for (dx, dy) in [(0.0, -1.2), (1.2, 0.0), (0.0, 1.2), (-1.2, 0.0)] {
                    path.addEllipse(in: CGRect(x: x + dx - 0.8, y: y + dy - 0.8, width: 1.6, height: 1.6))
                }
            }
            ctx.fill(path, with: p.red)
        case .ermine:
            var y = b.minY + 2
            var row = 0
            while y < b.maxY {
                let x = b.midX + (row % 2 == 0 ? -0.8 : 0.8)
                path.addRect(CGRect(x: x - 0.45, y: y - 0.9, width: 0.9, height: 1.8))
                y += 3.6; row += 1
            }
            ctx.fill(path, with: ink)
        case .none:
            break
        }
    }

    /// Calls `body` on a staggered grid covering `b`.
    private func grid(_ b: CGRect, step: CGFloat, rowStep: CGFloat, _ body: (CGFloat, CGFloat) -> Void) {
        var y = b.minY + rowStep * 0.7
        var row = 0
        while y < b.maxY {
            var x = b.minX + (row % 2 == 0 ? step / 2 : step)
            while x < b.maxX {
                body(x, y)
                x += step
            }
            y += rowStep; row += 1
        }
    }

    private func gem(_ ctx: inout GraphicsContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ shading: GraphicsContext.Shading) {
        let path = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        ctx.fill(path, with: shading)
        ctx.stroke(path, with: p.outline, lineWidth: p.lineWidth * 0.6)
    }

    private func poly(_ pts: [(CGFloat, CGFloat)]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: P(first.0, first.1))
        for pt in pts.dropFirst() { path.addLine(to: P(pt.0, pt.1)) }
        path.closeSubpath()
        return path
    }

    private func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}
