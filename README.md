# Solitaire

Klondike solitaire in two flavors.

## iOS app (`ios/`)

A native SwiftUI app that uses Liquid Glass (`glassEffect`, `GlassEffectContainer`,
`.glass` / `.glassProminent` button styles). It needs Xcode 26 or later and runs on iOS 26+,
including iOS 27.

```bash
cd ios && xcodegen generate && open Solitaire.xcodeproj
```

`Solitaire.xcodeproj` is generated from `ios/project.yml`. Edit the YAML, then rerun `xcodegen`.
Before you run it on a real device, set your own team and bundle ID (it's `com.example.solitaire` now).

- `Model/Klondike.swift`: the rules engine (pure value type with undo history)
- `Model/GameStore.swift`: observable store, persistence, timer
- `Views/GameView.swift`: the table, gestures, and Liquid Glass controls
- `Views/TableLayout.swift`: card geometry and drop-target hit testing
- `AppIcon.icon`: layered Liquid Glass app icon (open it in Icon Composer to edit)

Icon concepts and the script that generates them are in `design/icons/`
(`python3 design/icons/make_icons.py`).

## Web version (root)

Plain HTML/CSS/JS with no build step. Serve the folder (e.g. `python3 -m http.server`)
and open `index.html`.

## How to play

Tap a card to auto-move it. Drag cards or stacks to move them. Tap the stock to draw.
When every card is face up, use **Finish** to auto-complete.
