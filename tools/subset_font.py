#!/usr/bin/env python3
"""Subset the Noto Sans CJK TC font down to only the glyphs the game UI uses.

Reads every non-comment string literal in scripts/*.gd, plus full ASCII and
common CJK punctuation, and writes a tiny subset font for fast web loading.

Run from project root:  python3 tools/subset_font.py
"""
import glob
import re
from pathlib import Path
from fontTools import subset

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "fonts" / "NotoSansCJKtc-Regular.otf"
OUT = ROOT / "assets" / "fonts" / "GameFont.otf"


def collect_chars() -> set[str]:
    chars: set[str] = set()
    for f in glob.glob(str(ROOT / "scripts" / "*.gd")):
        for line in open(f, encoding="utf-8"):
            code = line.split("#", 1)[0]
            for lit in re.findall(r'"([^"]*)"', code):
                chars.update(lit)
    # Always keep full printable ASCII so English text/HUD renders.
    chars.update(chr(c) for c in range(0x20, 0x7f))
    # Common CJK punctuation that may appear in dynamic text.
    chars.update("　，。、！？：；（）「」『』…—·～％＋－")
    return {c for c in chars if c >= " "}


def main() -> None:
    chars = collect_chars()
    text = "".join(sorted(chars))
    print(f"Glyphs needed: {len(chars)} unique characters")

    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    options.drop_tables = ["DSIG"]

    font = subset.load_font(str(SRC), options)
    s = subset.Subsetter(options=options)
    s.populate(text=text)
    s.subset(font)
    subset.save_font(font, str(OUT), options)

    size = OUT.stat().st_size
    print(f"Wrote {OUT.name}: {size} bytes ({size/1024:.1f} KB)")


if __name__ == "__main__":
    main()
