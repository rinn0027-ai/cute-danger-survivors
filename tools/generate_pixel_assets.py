#!/usr/bin/env python3
import os
import struct
import zlib


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def rgba(hex_color):
    hex_color = hex_color.lstrip("#")
    if len(hex_color) == 6:
        hex_color += "ff"
    return tuple(int(hex_color[i:i + 2], 16) for i in range(0, 8, 2))


T = (0, 0, 0, 0)
P = {
    ".": T,
    "k": rgba("#17131f"),
    "K": rgba("#2a2436"),
    "o": rgba("#3a314a"),
    "w": rgba("#f7f0d8"),
    "s": rgba("#d8c48a"),
    "r": rgba("#e65d5d"),
    "R": rgba("#ff9b72"),
    "b": rgba("#5fc7e8"),
    "B": rgba("#286a92"),
    "g": rgba("#6fd36b"),
    "G": rgba("#2b8a55"),
    "p": rgba("#a378ff"),
    "P": rgba("#5f3fa6"),
    "y": rgba("#ffd464"),
    "Y": rgba("#b98328"),
    "m": rgba("#e879b9"),
    "M": rgba("#853a73"),
    "c": rgba("#78ffe1"),
    "C": rgba("#1c8f88"),
    "n": rgba("#8b6652"),
    "N": rgba("#4a342d"),
    "d": rgba("#232837"),
    "D": rgba("#30394f"),
    "x": rgba("#10131f"),
}


def write_png(path, rows, palette=None, scale=1):
    palette = palette or P
    h = len(rows)
    w = max(len(r) for r in rows)
    pixels = []
    for row in rows:
        row = row.ljust(w, ".")
        pixels.append([palette.get(ch, T) for ch in row])
    if scale != 1:
        scaled = []
        for line in pixels:
            wide = []
            for px in line:
                wide.extend([px] * scale)
            for _ in range(scale):
                scaled.append(wide[:])
        pixels = scaled
        h *= scale
        w *= scale
    raw = bytearray()
    for line in pixels:
        raw.append(0)
        for px in line:
            raw.extend(px)
    def chunk(tag, data):
        return (
            struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
        )
    data = (
        b"\x89PNG\r\n\x1a\n" +
        chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)) +
        chunk(b"IDAT", zlib.compress(bytes(raw), 9)) +
        chunk(b"IEND", b"")
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def write_svg(path, title, color):
    content = f'''<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96" shape-rendering="crispEdges">
<rect width="96" height="96" fill="#10131f"/>
<rect x="8" y="8" width="80" height="80" fill="#232837" stroke="#d8c48a" stroke-width="4"/>
<rect x="20" y="20" width="56" height="56" fill="{color}" stroke="#17131f" stroke-width="4"/>
<rect x="32" y="32" width="32" height="12" fill="#f7f0d8"/>
<rect x="28" y="52" width="40" height="8" fill="#17131f"/>
<title>{title}</title>
</svg>
'''
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)


FLOOR_ROWS = [
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "ddddDddddddddddddddddddddDddddd",
    "dddDDDddddddddddddddddddDDDdddd",
    "ddddDddddddddddddddddddddDddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "ddddddddddddDddddddddddddddddddd",
    "dddddddddddDDDdddddddddddddddddd",
    "ddddddddddddDddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "ddDddddddddddddddddddddddddddDdd",
    "dDDDddddddddddddddddddddddddDDDd",
    "ddDddddddddddddddddddddddddddDdd",
    "dddddddddddddddddddddddddddddddd",
    "ddddddddddddddddddddDddddddddddd",
    "dddddddddddddddddddDDDdddddddddd",
    "ddddddddddddddddddddDddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "ddddddddDddddddddddddddddddddddd",
    "dddddddDDDdddddddddddddddddddddd",
    "ddddddddDddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
    "dddddddddddddddddddddddddddddddd",
]


def floor_palette(base, highlight, accent):
    return {
        ".": T,
        "d": rgba(base),
        "D": rgba(highlight),
        "x": rgba(accent),
    }


def main():
    s = lambda name: os.path.join(ROOT, "assets", "sprites", name)
    write_png(s("player.png"), [
        "................",
        ".....yyyyyy.....",
        "....yKKKKKKy....",
        "...yKppppppKy...",
        "...KpwwppwwpK...",
        "...KppppppppK...",
        "....KpKppKpK....",
        "...KKKpKKpKKK...",
        "..KppppppppppK..",
        "..KpKppppppKpK..",
        "...KpKpKKpKpK...",
        "...KKK....KKK...",
        "....K......K....",
        "................",
        "................",
        "................",
    ], scale=3)
    write_png(s("slime.png"), [
        "................",
        "................",
        "....kkkkkkkk....",
        "...kGGGGGGGGk...",
        "..kGggGGGGggGk..",
        "..kGgwGGGGwgGk..",
        ".kGGGGGGGGGGGGk.",
        ".kGGGGGCCGGGGGk.",
        ".kGGGCCCCCCGGGk.",
        "..kGGCCCCCCGGk..",
        "...kkkkkkkkkk...",
        "................",
    ], scale=4)
    write_png(s("bat.png"), [
        "................",
        "..kk........kk..",
        ".kPPk......kPPk.",
        "kPPPPkkkkkkPPPPk",
        "kPPKPPPPPPPPKPPk",
        ".kkPPpPPPPpPPkk.",
        "...kPPwwwwPPk...",
        "....kPPPPPPk....",
        ".....kkPPkk.....",
        ".......kk.......",
        "................",
        "................",
    ], scale=4)
    floor_themes = {
        "floor.png": floor_palette("#232837", "#30394f", "#10131f"),
        "floor_spring.png": floor_palette("#24382f", "#456b45", "#f3a6c8"),
        "floor_summer.png": floor_palette("#203c34", "#4e8f52", "#ffd464"),
        "floor_autumn.png": floor_palette("#3a2b24", "#8b5a30", "#e8793e"),
        "floor_winter.png": floor_palette("#263342", "#8fb8d8", "#f7f0d8"),
        "floor_snow.png": floor_palette("#d7e8ef", "#ffffff", "#9ab7cf"),
    }
    for filename, palette in floor_themes.items():
        write_png(s(filename), FLOOR_ROWS, palette=palette, scale=2)
    custom_door = os.path.join(ROOT, "assets", "tiles", "medieval_door_tile.png")
    custom_topdown_door = os.path.join(ROOT, "assets", "tiles", "medieval_door_topdown_tile.png")
    if not os.path.exists(custom_door):
        write_png(s("door.png"), [
            "................",
            ".....yyyyyy.....",
            "...yyNNNNNNyy...",
            "..yNNNNNNNNNNy..",
            "..yNNKNNNNKNNy..",
            "..yNNNNccNNNNy..",
            "..yNNNNccNNNNy..",
            "..yNNNNNNNNNNy..",
            "..yNNNNyyNNNNy..",
            "..yNNNNyyNNNNy..",
            "..yNNNNNNNNNNy..",
            "..yyyyyyyyyyyy..",
            "................",
        ], scale=4)
    if not os.path.exists(custom_topdown_door):
        write_png(s("door_topdown.png"), [
            "................",
            "...yyyyyyyyyy...",
            "..yNNNNNNNNNNy..",
            ".yNNNccccNNNNy.",
            ".yNNNccccNNNNy.",
            "..yNNNNNNNNNNy..",
            "...yyyyyyyyyy...",
            "................",
        ], scale=6)
    write_png(s("gem.png"), [
        "................",
        "......cccc......",
        ".....cwwwwc.....",
        "....cwbbbbwc....",
        "...cwbbCCbbwc...",
        "....cwbbbbwc....",
        ".....cwwwwc.....",
        "......cccc......",
        "................",
    ], scale=3)
    icon_rows = {
        "icon_damage.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY....rr....Yk.",
            ".kY...rRRr...Yk.", ".kY..rRyyRr..Yk.", ".kY...rRRr...Yk.", ".kY....rr....Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_speed.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY..c.....c.Yk.",
            ".kY...c...c..Yk.", ".kY....c.c...Yk.", ".kY..bbbbbbb.Yk.", ".kY....c.c...Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_pierce.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY....p.....Yk.",
            ".kY...pwp....Yk.", ".kY..pwwwp...Yk.", ".kY....p.....Yk.", ".kY..mmmmmm..Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_heart.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY..rr..rr..Yk.",
            ".kY.rmmrrmmr.Yk.", ".kY.rmmmmmmr.Yk.", ".kY..rmmmmr..Yk.", ".kY....rr....Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_crown.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY.y..y..y..Yk.",
            ".kY.yysyysy..Yk.", ".kY..yyyyyy..Yk.", ".kY..ssssss..Yk.", ".kY..........Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_trigger.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY..bbbbbb..Yk.",
            ".kY.bccccccb.Yk.", ".kY....cc...Yk.", ".kY...cc....Yk.", ".kY..cc.....Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_falcon.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY....ww....Yk.",
            ".kY...wbbww..Yk.", ".kY..wbbbbbw.Yk.", ".kY....bb...Yk.", ".kY...b..b..Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_triple.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY..c..c..c.Yk.",
            ".kY.cc.cc.cc.Yk.", ".kY..c..c..c.Yk.", ".kY....bbb...Yk.", ".kY...bbbbb..Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_magnet.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY.pp....pp.Yk.",
            ".kY.pw....wp.Yk.", ".kY.pw....wp.Yk.", ".kY..pppppp..Yk.", ".kY...mmmm...Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_giant.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY...yyyy...Yk.",
            ".kY..ywwwwy..Yk.", ".kY.ywwwwwwy.Yk.", ".kY..ywwwwy..Yk.", ".kY...yyyy...Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_void.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY..p....p..Yk.",
            ".kY...pmmmp..Yk.", ".kY..mmwwmm..Yk.", ".kY...pmmmp..Yk.", ".kY..p....p..Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
        "icon_focus.png": [
            "................", "...kkkkkkkkkk...", "..kYYYYYYYYYYk..", ".kY....y.....Yk.",
            ".kY...ywy....Yk.", ".kY..ywwwy...Yk.", ".kY....y.....Yk.", ".kY..cccccc..Yk.",
            "..kYYYYYYYYYYk..", "...kkkkkkkkkk...", "................",
        ],
    }
    for name, rows in icon_rows.items():
        write_png(s(name), rows, scale=3)
    # PWA / export splash icons.
    write_png(os.path.join(ROOT, "assets", "visual_direction.png"), [
        "kkkkkkkkkkkkkkkk",
        "kYYYYYYYYYYYYYYk",
        "kY............Yk",
        "kY....cccc....Yk",
        "kY...cwwwwc...Yk",
        "kY..cwkwwkc..Yk",
        "kY...cwwwwc...Yk",
        "kY....cccc....Yk",
        "kY............Yk",
        "kYYYYYYYYYYYYYYk",
        "kkkkkkkkkkkkkkkk",
    ], scale=8)
    for folder, stem in [("docs", "index"), ("build/web", "index"), ("build/web", "rogue")]:
        base = os.path.join(ROOT, folder)
        if os.path.isdir(base):
            for suffix in ["png", "icon.png", "apple-touch-icon.png", "144x144.png", "180x180.png", "512x512.png"]:
                write_png(os.path.join(base, f"{stem}.{suffix}"), [
                    "kkkkkkkkkkkkkkkk",
                    "kYYYYYYYYYYYYYYk",
                    "kY..pppppppp..Yk",
                    "kY.ppwwppwwpp.Yk",
                    "kY.ppppccpppp.Yk",
                    "kY..pppppppp..Yk",
                    "kY...kkkkkk...Yk",
                    "kY..kcccccck..Yk",
                    "kY.kccwwwwcck.Yk",
                    "kY..kcccccck..Yk",
                    "kY............Yk",
                    "kYYYYYYYYYYYYYYk",
                    "kkkkkkkkkkkkkkkk",
                ], scale=32)
    asset_dir = os.path.join(ROOT, "assets")
    write_svg(os.path.join(asset_dir, "player_hero.svg"), "Card Rogue Hero", "#a378ff")
    write_svg(os.path.join(asset_dir, "enemy_slime.svg"), "Card Rogue Slime", "#6fd36b")
    write_svg(os.path.join(asset_dir, "enemy_bat.svg"), "Card Rogue Bat", "#a378ff")
    write_svg(os.path.join(asset_dir, "tile_floor.svg"), "Rune Floor", "#30394f")
    write_svg(os.path.join(asset_dir, "ui_heart.svg"), "Heart Card", "#e65d5d")
    write_svg(os.path.join(asset_dir, "xp_gem.svg"), "XP Gem Card", "#78ffe1")


if __name__ == "__main__":
    main()
