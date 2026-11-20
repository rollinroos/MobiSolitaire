import SwiftUI

@main
struct SolitaireApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(.dark)
        }
    }
}
