#!/usr/bin/env python3
"""Author and patch Pico-8 8x8 sprites without an external image editor.

A sprite is a plain-text file: 8 lines, each 8 hex characters (0-f), one
Pico-8 palette index per pixel. See sprite_tool.py --help for subcommands.

No third-party dependencies (PNG output is hand-rolled via zlib/struct so
this runs with a stock python3).
"""
import argparse
import math
import random
import struct
import subprocess
import sys
import zlib
from pathlib import Path


def maybe_open(path, do_open):
    """Launch the OS image viewer on a written preview, unless suppressed.

    Default-on: previews are for a human to look at, and a printed path
    nobody follows isn't a review step. --no-open opts out (scripting, CI).
    """
    if do_open and sys.platform == "darwin":
        subprocess.run(["open", str(path)], check=False)

# Standard Pico-8 palette (RGB), indices 0-15.
PALETTE_NAMES = [
    "black", "dark blue", "dark purple", "dark green",
    "brown", "dark grey", "light grey", "white",
    "red", "orange", "yellow", "green",
    "teal", "dark red", "pink", "peach",
]
# Block glyphs, one per palette index, for terminal ASCII rendering
# (ANSI truecolour doesn't render in all consoles, so shape/glyph carries
# the signal instead of colour; index 0 is always background/transparent).
SYMBOLS = " #@%+=*o0xX&$~^:;"[:16]

PALETTE = [
    (0, 0, 0), (29, 43, 83), (126, 37, 83), (0, 135, 81),
    (171, 82, 54), (95, 87, 79), (194, 195, 199), (255, 241, 232),
    (255, 0, 77), (255, 163, 0), (255, 236, 39), (0, 228, 54),
    (41, 173, 255), (131, 118, 156), (255, 119, 168), (255, 204, 170),
]


def load_sprite(path):
    lines = [l.strip() for l in Path(path).read_text().splitlines() if l.strip()]
    if len(lines) != 8 or any(len(l) != 8 for l in lines):
        raise ValueError(f"{path}: expected 8 lines of 8 hex chars, got {lines}")
    return [[int(c, 16) for c in line] for line in lines]


def write_png(rgb_rows, path, scale=32):
    w = len(rgb_rows[0]) * scale
    h = len(rgb_rows) * scale
    raw = bytearray()
    for row in rgb_rows:
        scaled_row = b"".join(bytes(row[x]) * scale for x in range(len(row)))
        for _ in range(scale):
            raw.append(0)  # filter byte
            raw.extend(scaled_row)

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def cmd_preview(args):
    grid = load_sprite(args.sprite)
    rgb_rows = [[PALETTE[c] for c in row] for row in grid]
    write_png(rgb_rows, args.out, scale=args.scale)
    print(f"wrote {args.out}")
    maybe_open(args.out, args.open)


GRID_LINE = (60, 60, 60)


def cmd_sheet(args):
    """Render several sprites into one PNG, side by side with a grid line
    between them, so multiple defs can be reviewed in a single image."""
    grids = [load_sprite(p) for p in args.sprites]
    rgb_rows = []
    for row_i in range(8):
        row = []
        for i, grid in enumerate(grids):
            if i > 0:
                row.append(GRID_LINE)
            row.extend(PALETTE[c] for c in grid[row_i])
        rgb_rows.append(row)
    write_png(rgb_rows, args.out, scale=args.scale)
    print(f"wrote {args.out} ({len(grids)} sprites: {', '.join(Path(p).stem for p in args.sprites)})")
    maybe_open(args.out, args.open)


def sprite_hex_rows(grid):
    """8 rows of 8 hex chars (low nibble = left pixel, per Pico-8 __gfx__ spec)."""
    return ["".join(f"{c:x}" for c in row) for row in grid]


def cmd_ascii(args):
    """Print sprite(s) side by side as glyph grids, for fast terminal review.

    Each palette index maps to a fixed glyph (see SYMBOLS); a legend below
    lists which glyph is which colour whenever a sprite uses more than
    black/one foreground colour. Glyphs, not ANSI colour, carry the shape
    signal here since not every console this runs in renders 24-bit colour.
    Pass --color to switch to ANSI truecolour blocks on consoles that do.
    """
    sprites = [load_sprite(p) for p in args.sprites]
    labels = [Path(p).stem for p in args.sprites]

    gap = "  "
    if args.color:
        def cell(c):
            r, g, b = PALETTE[c]
            return f"\x1b[48;2;{r};{g};{b}m  \x1b[0m"
    else:
        cell = lambda c: f"{SYMBOLS[c]} "
    header = gap.join(label.center(16) for label in labels)
    print(header)
    for row_i in range(8):
        line_parts = ["".join(cell(c) for c in grid[row_i]) for grid in sprites]
        print(gap.join(line_parts))
    print()

    used = sorted({c for grid in sprites for row in grid for c in row} - {0})
    if used and not args.color:
        legend = "  ".join(f"{SYMBOLS[c]}={PALETTE_NAMES[c]}({c})" for c in used)
        print("legend: " + legend)


def pat_solid(rng, base, accent, **kw):
    return [[base] * 8 for _ in range(8)]


def pat_lines(rng, base, accent, rows=None, jitter=False, **kw):
    """Horizontal accent line(s). --jitter breaks each row into dashes at a
    random per-row offset, for a wavy-highlight/wave-line look."""
    grid = [[base] * 8 for _ in range(8)]
    c = accent if accent is not None else base
    for r in rows or [2, 5]:
        if 0 <= r < 8:
            off = rng.randint(0, 2) if jitter else 0
            for x in range(8):
                if not jitter or (x + off) % 3 != 0:
                    grid[r][x] = c
    return grid


def pat_hatch(rng, base, accent, spacing=3, **kw):
    """Diagonal cross-hatch (both diagonals) at a fixed spacing."""
    grid = [[base] * 8 for _ in range(8)]
    c = accent if accent is not None else 0
    for y in range(8):
        for x in range(8):
            if (x + y) % spacing == 0 or (x - y) % spacing == 0:
                grid[y][x] = c
    return grid


def pat_cracks(rng, base, accent, segments=2, **kw):
    """A few short angled line segments, for sharp/angular crack texture."""
    grid = [[base] * 8 for _ in range(8)]
    c = accent if accent is not None else 0
    for _ in range(segments):
        x, y = rng.randint(0, 5), rng.randint(0, 5)
        length = rng.randint(3, 5)
        dx, dy = rng.choice([(1, 1), (1, 0), (1, -1)])
        for i in range(length):
            xx, yy = x + i * dx, y + i * dy
            if 0 <= xx < 8 and 0 <= yy < 8:
                grid[yy][xx] = c
    return grid


def pat_dots(rng, base, accent, density=0.15, cluster=False, **kw):
    """Scattered accent pixels. --cluster groups them around 1-2 centres
    instead of spreading uniformly (moss patches vs. even speckle)."""
    grid = [[base] * 8 for _ in range(8)]
    c = accent if accent is not None else base
    if cluster:
        centers = [(rng.randint(1, 6), rng.randint(1, 6)) for _ in range(rng.randint(1, 2))]
        n = max(3, round(64 * density))
        for _ in range(n):
            cx, cy = rng.choice(centers)
            x = min(7, max(0, cx + rng.randint(-2, 2)))
            y = min(7, max(0, cy + rng.randint(-2, 2)))
            grid[y][x] = c
    else:
        for y in range(8):
            for x in range(8):
                if rng.random() < density:
                    grid[y][x] = c
    return grid


def pat_blobs(rng, base, accent, count=2, size=2, **kw):
    """A few small diamond-shaped clusters (ore nuggets / gem facets)."""
    grid = [[base] * 8 for _ in range(8)]
    c = accent if accent is not None else base
    for _ in range(count):
        cx, cy = rng.randint(1, 6), rng.randint(1, 6)
        for dy in range(-size, size + 1):
            for dx in range(-size, size + 1):
                x, y = cx + dx, cy + dy
                if 0 <= x < 8 and 0 <= y < 8 and abs(dx) + abs(dy) <= size:
                    grid[y][x] = c
    return grid


def pat_radial(rng, base, accent, core=None, **kw):
    """A bright 2x2 core with accent dots radiating outward in a ring."""
    grid = [[base] * 8 for _ in range(8)]
    c = accent if accent is not None else base
    core_c = core if core is not None else 7
    for y in (3, 4):
        for x in (3, 4):
            grid[y][x] = core_c
    for ang in range(0, 360, 45):
        x = round(3.5 + 2.6 * math.cos(math.radians(ang)))
        y = round(3.5 + 2.6 * math.sin(math.radians(ang)))
        if 0 <= x < 8 and 0 <= y < 8:
            grid[y][x] = c
    return grid


PATTERNS = {
    "solid": pat_solid,
    "lines": pat_lines,
    "hatch": pat_hatch,
    "cracks": pat_cracks,
    "dots": pat_dots,
    "blobs": pat_blobs,
    "radial": pat_radial,
}


def cmd_generate(args):
    rng = random.Random(args.seed)
    rows = [int(r) for r in args.rows.split(",")] if args.rows else None
    grid = PATTERNS[args.pattern](
        rng, args.base, args.accent,
        rows=rows, jitter=args.jitter, density=args.density, cluster=args.cluster,
        count=args.count, size=args.size, core=args.core, spacing=args.spacing,
        segments=args.segments,
    )
    text = "\n".join(sprite_hex_rows(grid)) + "\n"
    Path(args.out).write_text(text)
    print(f"wrote {args.out} (pattern={args.pattern}, base={args.base}, accent={args.accent}, seed={args.seed})")


def gfx_start_line(lines):
    """Return the line index of __gfx__'s first data row, inserting a blank
    section (in canonical position) first if the cart doesn't have one yet."""
    try:
        return lines.index("__gfx__") + 1
    except ValueError:
        # No __gfx__ section yet: insert one right after __lua__'s content,
        # i.e. before __label__/__gff__/__sfx__/__map__, whichever comes first.
        insert_at = len(lines)
        for marker in ("__label__", "__gff__", "__sfx__", "__map__", "__music__"):
            if marker in lines:
                insert_at = lines.index(marker)
                break
        blank_row = "0" * 128
        gfx_block = ["__gfx__"] + [blank_row] * 128
        lines[insert_at:insert_at] = gfx_block
        return insert_at + 1


def apply_patch(lines, sprite_path, idx):
    """Patch one sprite into `lines` (a cart's text, split on \\n) in place."""
    grid = load_sprite(sprite_path)
    new_rows = sprite_hex_rows(grid)  # 8 rows x 8 chars for this one sprite
    sx = (idx % 16) * 8  # char column within a 128-char gfx row
    sy = (idx // 16) * 8  # gfx row

    gfx_start = gfx_start_line(lines)
    for i in range(8):
        row = lines[gfx_start + sy + i]
        if len(row) < 128:
            row = row.ljust(128, "0")
        lines[gfx_start + sy + i] = row[:sx] + new_rows[i] + row[sx + 8:]


def cmd_patch(args):
    cart = Path(args.cart)
    lines = cart.read_text().split("\n")
    apply_patch(lines, args.sprite, args.index)
    cart.write_text("\n".join(lines))
    print(f"patched sprite {args.index} into {args.cart}")


def cmd_patch_all(args):
    """Batch-patch many sprites into a cart from a manifest file.

    Manifest format: one `index path` pair per line (whitespace-separated),
    `#` starts a comment, blank lines ignored. Loads and saves the cart once
    regardless of manifest size, instead of once per sprite.
    """
    cart = Path(args.cart)
    lines = cart.read_text().split("\n")
    count = 0
    for lineno, raw in enumerate(Path(args.manifest).read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            raise ValueError(f"{args.manifest}:{lineno}: expected 'index path', got {raw!r}")
        idx_str, sprite_path = parts
        apply_patch(lines, sprite_path.strip(), int(idx_str))
        count += 1
    cart.write_text("\n".join(lines))
    print(f"patched {count} sprites into {args.cart} from {args.manifest}")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    sub = p.add_subparsers(dest="cmd", required=True)

    pv = sub.add_parser("preview", help="render a sprite file to a scaled-up PNG")
    pv.add_argument("sprite", help="path to an 8x8 hex-grid sprite file")
    pv.add_argument("out", help="output PNG path")
    pv.add_argument("--scale", type=int, default=32)
    pv.add_argument("--no-open", dest="open", action="store_false", help="don't launch the OS viewer")
    pv.set_defaults(func=cmd_preview)

    sh = sub.add_parser("sheet", help="render several sprites side by side into one PNG")
    sh.add_argument("sprites", nargs="+", help="two or more sprite files to lay out left to right")
    sh.add_argument("out", help="output PNG path")
    sh.add_argument("--scale", type=int, default=24)
    sh.add_argument("--no-open", dest="open", action="store_false", help="don't launch the OS viewer")
    sh.set_defaults(func=cmd_sheet)

    pa = sub.add_parser("patch", help="write a sprite into a cart's __gfx__ section")
    pa.add_argument("cart", help="path to the .p8 cartridge file")
    pa.add_argument("sprite", help="path to an 8x8 hex-grid sprite file")
    pa.add_argument("index", type=int, help="sprite sheet slot, 0-255")
    pa.set_defaults(func=cmd_patch)

    pall = sub.add_parser("patch-all", help="batch-patch many sprites into a cart from a manifest")
    pall.add_argument("cart", help="path to the .p8 cartridge file")
    pall.add_argument("manifest", help="text file of 'index path' lines, # comments allowed")
    pall.set_defaults(func=cmd_patch_all)

    gen = sub.add_parser("generate", help="generate a starter 8x8 sprite from a pattern primitive")
    gen.add_argument("pattern", choices=sorted(PATTERNS), help="pattern primitive to use")
    gen.add_argument("out", help="output sprite file path")
    gen.add_argument("--base", type=int, required=True, help="base/fill palette index, 0-15")
    gen.add_argument("--accent", type=int, default=None, help="accent palette index, 0-15 (pattern picks a default if omitted)")
    gen.add_argument("--seed", type=int, default=0, help="RNG seed, for reproducible output")
    gen.add_argument("--density", type=float, default=0.15, help="dots: fraction of pixels set (0-1)")
    gen.add_argument("--cluster", action="store_true", help="dots: scatter around 1-2 cluster centres instead of uniformly")
    gen.add_argument("--count", type=int, default=2, help="blobs: number of blobs")
    gen.add_argument("--size", type=int, default=2, help="blobs: blob radius in pixels")
    gen.add_argument("--core", type=int, default=None, help="radial: bright core colour (default 7/white)")
    gen.add_argument("--spacing", type=int, default=3, help="hatch: line spacing")
    gen.add_argument("--segments", type=int, default=2, help="cracks: number of crack segments")
    gen.add_argument("--rows", default=None, help="lines: comma-separated row indices, e.g. '2,5'")
    gen.add_argument("--jitter", action="store_true", help="lines: break/offset each row for a wavy look")
    gen.set_defaults(func=cmd_generate)

    asc = sub.add_parser("ascii", help="print sprite(s) as glyph grids in the terminal")
    asc.add_argument("sprites", nargs="+", help="one or more sprite files to show side by side")
    asc.add_argument("--color", action="store_true", help="use ANSI truecolour blocks instead of glyphs")
    asc.set_defaults(func=cmd_ascii)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    sys.exit(main())
