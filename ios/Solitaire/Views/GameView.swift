import SwiftUI

struct GameView: View {
    @State private var store = GameStore()
    @State private var drag: DragState?
    @State private var finishing = false
    @State private var pendingDrawCount: Int?
    @AppStorage("cardStyle") private var cardStyleRaw = CardStyle.classic.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var glass

    private var cardStyle: CardStyle { CardStyle(rawValue: cardStyleRaw) ?? .classic }

    private struct DragState {
        var from: PileRef
        var index: Int
        var ids: Set<String>
        var origin: CGPoint
        var translation: CGSize = .zero
    }

    private var game: Klondike { store.game }

    var body: some View {
        GeometryReader { geo in
            let layout = TableLayout(size: geo.size)
            table(layout)
        }
        .environment(\.cardStyle, cardStyle)
        .padding(.top, 12)
        .background { FeltBackground().ignoresSafeArea() }
        .safeAreaInset(edge: .top) { header }
        .safeAreaInset(edge: .bottom) { controls }
        .overlay {
            if game.won { winPanel }
        }
        .confirmationDialog("Start a new game?", isPresented: confirmBinding, titleVisibility: .visible) {
            Button("New Game", role: .destructive) {
                if let count = pendingDrawCount { startNewGame(drawCount: count) }
            }
        } message: {
            Text("Your current game will be lost.")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: game.moves)
        .sensoryFeedback(.warning, trigger: store.rejections)
        .sensoryFeedback(.success, trigger: game.won) { _, won in won }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                store.tick()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            store.isActive = phase == .active
            if phase != .active { store.save() }
        }
    }

    // MARK: Table

    private func table(_ layout: TableLayout) -> some View {
        ZStack(alignment: .topLeading) {
            slots(layout)

            ForEach(layout.placements(for: game.table, drawCount: game.drawCount)) { placement in
                cardView(placement, layout)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Empty pile outlines rendered as clear Liquid Glass wells.
    private func slots(_ layout: TableLayout) -> some View {
        let shape = RoundedRectangle(cornerRadius: layout.cornerRadius, style: .continuous)
        let suits = Suit.allCases
        return GlassEffectContainer(spacing: layout.gap) {
            ZStack(alignment: .topLeading) {
                ForEach([PileRef.stock] + PileRef.dropTargets, id: \.self) { pile in
                    ZStack {
                        if case .foundation(let i) = pile {
                            Text(suits[i].symbol)
                                .font(.system(size: layout.cardSize.width * 0.42))
                                .foregroundStyle(.white.opacity(0.28))
                        }
                        if pile == .stock && game.table.stock.isEmpty && !game.table.waste.isEmpty {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: layout.cardSize.width * 0.36, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    .frame(width: layout.cardSize.width, height: layout.cardSize.height)
                    .glassEffect(.clear, in: shape)
                    .contentShape(shape)
                    .onTapGesture { if pile == .stock { draw() } }
                    .position(layout.slotCenter(pile))
                }
            }
        }
    }

    private func cardView(_ p: CardPlacement, _ layout: TableLayout) -> some View {
        let isDragged = drag?.ids.contains(p.card.id) == true
        let z = isDragged ? 1000 + Double(p.index)
            : p.z + (store.lastMoved.contains(p.card.id) ? 500 : 0)
        return CardView(card: p.card, size: layout.cardSize, raised: p.raised || isDragged)
            .rotation3DEffect(.degrees(isDragged ? tilt(drag!.translation.width) : 0),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(isDragged ? -tilt(drag!.translation.height) * 0.6 : 0),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .scaleEffect(isDragged ? 1.08 : 1)
            .shadow(color: .black.opacity(isDragged ? 0.35 : 0), radius: 14, y: 12)
            .offset(isDragged ? drag!.translation : .zero)
            .onTapGesture { tap(p) }
            .gesture(dragGesture(p, layout))
            .position(p.center)
            .zIndex(z)
            .allowsHitTesting(!finishing)
    }

    /// Lifts and leans the card toward the direction it's dragged, up to 12°.
    private func tilt(_ distance: CGFloat) -> Double {
        max(-12, min(12, Double(distance) * 0.08))
    }

    private func dragGesture(_ p: CardPlacement, _ layout: TableLayout) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                if drag == nil {
                    guard game.canPick(p.pile, p.index) else { return }
                    let ids = Set(game.table[p.pile][p.index...].map(\.id))
                    withAnimation(.snappy(duration: 0.15)) {
                        drag = DragState(from: p.pile, index: p.index, ids: ids, origin: p.center)
                    }
                }
                drag?.translation = value.translation
            }
            .onEnded { value in
                guard let d = drag else { return }
                let dropCenter = CGPoint(x: d.origin.x + value.translation.width,
                                         y: d.origin.y + value.translation.height)
                let target = layout.dropTarget(cardCenter: dropCenter, from: d.from, index: d.index, game: game)
                withAnimation(.snappy(duration: 0.28)) {
                    if let target {
                        store.move(from: d.from, index: d.index, to: target)
                    } else {
                        store.reject()
                    }
                    drag = nil
                }
            }
    }

    private func tap(_ p: CardPlacement) {
        guard !finishing else { return }
        if p.pile == .stock {
            draw()
            return
        }
        guard p.card.faceUp else { return }
        withAnimation(.snappy(duration: 0.28)) {
            _ = store.autoMove(from: p.pile, index: p.index)
        }
    }

    // MARK: Actions

    private func draw() {
        guard !finishing else { return }
        withAnimation(.snappy(duration: 0.25)) { store.draw() }
    }

    private func undo() {
        guard !finishing else { return }
        withAnimation(.snappy(duration: 0.28)) { store.undo() }
    }

    private func requestNewGame(drawCount: Int) {
        if game.started && !game.won {
            pendingDrawCount = drawCount
        } else {
            startNewGame(drawCount: drawCount)
        }
    }

    private func startNewGame(drawCount: Int) {
        pendingDrawCount = nil
        finishing = false
        withAnimation(.smooth(duration: 0.45)) { store.newGame(drawCount: drawCount) }
    }

    private func autoFinish() {
        guard !finishing, game.canAutoFinish else { return }
        withAnimation(.snappy) { finishing = true }
        Task {
            while true {
                var moved = false
                withAnimation(.snappy(duration: 0.22)) { moved = store.autoFinishStep() }
                if !moved { break }
                try? await Task.sleep(for: .milliseconds(120))
            }
            withAnimation(.snappy) { finishing = false }
        }
    }

    private var confirmBinding: Binding<Bool> {
        Binding(get: { pendingDrawCount != nil }, set: { if !$0 { pendingDrawCount = nil } })
    }

    // MARK: Chrome

    private var header: some View {
        HStack {
            Text("Solitaire")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            HStack(spacing: 14) {
                Label("\(game.moves)", systemImage: "hand.tap")
                Label(Self.formatTime(game.elapsed), systemImage: "timer")
            }
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(.regular, in: .capsule)

            Button {
                withAnimation(.smooth(duration: 0.35)) { cardStyleRaw = cardStyle.next.rawValue }
            } label: {
                Image(systemName: cardStyle.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Card style: \(cardStyle.name)")
            .accessibilityHint("Switches to \(cardStyle.next.name) cards")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                Button { requestNewGame(drawCount: game.drawCount) } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.glass)

                Menu {
                    Picker("Draw", selection: Binding(
                        get: { game.drawCount },
                        set: { count in if count != game.drawCount { requestNewGame(drawCount: count) } }
                    )) {
                        Label("Draw 1", systemImage: "1.square").tag(1)
                        Label("Draw 3", systemImage: "3.square").tag(3)
                    }
                } label: {
                    Label("Draw \(game.drawCount)", systemImage: "rectangle.stack")
                }
                .buttonStyle(.glass)

                Button(action: undo) {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .disabled(!game.canUndo || finishing)

                if game.canAutoFinish || finishing {
                    Button(action: autoFinish) {
                        Label("Finish", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(finishing)
                    .glassEffectID("finish", in: glass)
                }
            }
            .controlSize(.large)
        }
        .animation(.bouncy, value: game.canAutoFinish)
        .padding(.bottom, 8)
    }

    private var winPanel: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.yellow.gradient)
                Text("You Won!")
                    .font(.largeTitle.weight(.bold))
                Text("\(game.moves) moves · \(Self.formatTime(game.elapsed))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Button("Play Again") { startNewGame(drawCount: game.drawCount) }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 32)
            .glassEffect(.regular, in: .rect(cornerRadius: 34))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    static func formatTime(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Deep green felt with a soft mesh gradient so the glass has something to refract.
struct FeltBackground: View {
    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.55, 0.45], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                Color(red: 0.07, green: 0.33, blue: 0.27), Color(red: 0.10, green: 0.45, blue: 0.36), Color(red: 0.06, green: 0.30, blue: 0.30),
                Color(red: 0.05, green: 0.27, blue: 0.22), Color(red: 0.09, green: 0.38, blue: 0.30), Color(red: 0.05, green: 0.25, blue: 0.25),
                Color(red: 0.03, green: 0.17, blue: 0.15), Color(red: 0.04, green: 0.20, blue: 0.17), Color(red: 0.03, green: 0.15, blue: 0.16),
            ]
        )
    }
}

#Preview {
    GameView()
        .preferredColorScheme(.dark)
}
