import SwiftUI

@main
struct SolitaireApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-CardGallery") {
                // Render straight to a PNG; drawing the whole gallery on screen overloads the simulator's GPU.
                Text("Rendering card gallery…")
                    .task { CardStyleGallery.renderPNG() }
            } else {
                GameView().preferredColorScheme(.dark)
            }
            #else
            GameView().preferredColorScheme(.dark)
            #endif
        }
    }
}
