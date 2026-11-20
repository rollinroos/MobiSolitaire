#!/usr/bin/env python3
"""Generate three Liquid Glass app-icon concepts (Icon Composer .icon bundles).

Each concept is three fanned playing cards. Every card body and every pip is its
own glass layer, so the system renders depth, specular edges and the dark,
tinted and clear appearances. Run:  python3 design/icons/make_icons.py
"""
import json
import pathlib

OUT = pathlib.Path(__file__).resolve().parent

# Suit shapes drawn in a 100x100 box.
SUIT_PATHS = {
    "heart": "M50 90C22 68 4 50 4 31C4 15 16 4 30 4C40 4 47 10 50 18C53 10 60 4 70 4C84 4 96 15 96 31C96 50 78 68 50 90Z",
    "diamond": "M50 2L88 50L50 98L12 50Z",
    "spade": "M50 4C80 30 96 46 96 62C96 77 85 87 71 87C63 87 56 83 52 76Q54 89 66 97H34Q46 89 48 76C44 83 37 87 29 87C15 87 4 77 4 62C4 46 20 30 50 4Z",
    "club": ("M50 6A21 21 0 0 1 69 36A21 21 0 1 1 55 72Q57 88 67 97H33Q43 88 45 72"
             "A21 21 0 1 1 31 36A21 21 0 0 1 50 6Z"),
}

CARD_W, CARD_H, CARD_R = 320, 448, 48
PIVOT = (512, 1000)
ANGLES = (-20, 0, 20)
CENTER = (512, 520)


def card_transform(angle):
    x = CENTER[0] - CARD_W / 2
    y = CENTER[1] - CARD_H / 2
    return f"rotate({angle} {PIVOT[0]} {PIVOT[1]}) translate({x} {y})"


def svg(body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
            f'viewBox="0 0 1024 1024">{body}</svg>\n')


def card_svg(angle, fill, stroke=None):
    s = f' stroke="{stroke}" stroke-width="3"' if stroke else ""
    return svg(f'<g transform="{card_transform(angle)}">'
               f'<rect width="{CARD_W}" height="{CARD_H}" rx="{CARD_R}" fill="{fill}"{s}/></g>')


def pip_svg(angle, suit, color):
    path = SUIT_PATHS[suit]
    big = 1.6             # center pip: 160px
    small = 0.72          # corner pip: 72px
    cx = CARD_W / 2 - 50 * big
    cy = CARD_H / 2 - 50 * big + 18
    return svg(f'<g transform="{card_transform(angle)}" fill="{color}">'
               f'<path transform="translate({cx} {cy}) scale({big})" d="{path}"/>'
               f'<path transform="translate(26 26) scale({small})" d="{path}"/>'
               f'<path transform="translate({CARD_W - 26} {CARD_H - 26}) rotate(180) scale({small})" d="{path}"/>'
               '</g>')


CONCEPTS = {
    "A-Felt": {
        "title": "Felt Classic",
        "fill": ["srgb:0.14902,0.53333,0.41176,1.00000", "srgb:0.03529,0.21176,0.16471,1.00000"],
        "cards": [
            ("spade", "#FDFBF6", None, "#1B2130"),
            ("heart", "#FDFBF6", None, "#D7263D"),
            ("diamond", "#FDFBF6", None, "#D7263D"),
        ],
        "translucency": False,
    },
    "B-Midnight": {
        "title": "Midnight Glass",
        "fill": ["srgb:0.13725,0.17647,0.36863,1.00000", "srgb:0.02353,0.03137,0.09020,1.00000"],
        "cards": [
            ("spade", "rgba(255,255,255,0.30)", "rgba(255,255,255,0.55)", "#FFFFFF"),
            ("heart", "rgba(255,255,255,0.30)", "rgba(255,255,255,0.55)", "#FF4D6D"),
            ("club", "rgba(255,255,255,0.30)", "rgba(255,255,255,0.55)", "#5CE1FF"),
        ],
        "translucency": True,
    },
    "C-Aurora": {
        "title": "Aurora",
        "fill": ["srgb:1.00000,0.54118,0.36078,1.00000", "srgb:0.43922,0.21961,0.86275,1.00000"],
        "cards": [
            ("spade", "#27C9B4", None, "#FFFFFF"),
            ("heart", "#FFC23D", None, "#FFFFFF"),
            ("diamond", "#FF4F9A", None, "#FFFFFF"),
        ],
        "translucency": True,
    },
}


def build(name, spec):
    bundle = OUT / f"{name}.icon"
    assets = bundle / "Assets"
    assets.mkdir(parents=True, exist_ok=True)
    layers = []
    # Layers are listed top-most first: right card above middle above left.
    for i in reversed(range(3)):
        suit, card_fill, stroke, pip_color = spec["cards"][i]
        angle = ANGLES[i]
        card_file, pip_file = f"card{i + 1}.svg", f"pip{i + 1}.svg"
        (assets / card_file).write_text(card_svg(angle, card_fill, stroke))
        (assets / pip_file).write_text(pip_svg(angle, suit, pip_color))
        layers.append({"glass": True, "image-name": pip_file, "name": f"pip{i + 1}"})
        layers.append({"glass": True, "image-name": card_file, "name": f"card{i + 1}"})
    doc = {
        "fill": {"linear-gradient": spec["fill"]},
        "groups": [{
            "layers": layers,
            "shadow": {"kind": "layer-color" if spec["translucency"] else "neutral", "opacity": 0.5},
            "specular": True,
            "translucency": {"enabled": spec["translucency"], "value": 0.4},
        }],
        "supported-platforms": {"squares": ["iOS"]},
    }
    (bundle / "icon.json").write_text(json.dumps(doc, indent=2) + "\n")
    return bundle


if __name__ == "__main__":
    for name, spec in CONCEPTS.items():
        print(build(name, spec))
