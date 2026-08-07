#!/usr/bin/env python3
"""Author and patch TIC-80 8x8 sprites without an external image editor.

A sprite is a plain-text file: 8 lines, each 8 hex characters (0-f), one
palette index per pixel — the same def format as
`tools/sprites/sprite_tool.py`'s Pico-8 version. See --help for subcommands.

Differs from the Pico-8 tool in two structural ways, both dictated by
TIC-80 itself (see ../tic80.md):

1. Two independent 256-slot banks (tiles, sprites) instead of one shared
   256-slot sheet — every patch/dump/verify command takes a `--bank`
   ("tiles" or "sprites") to say which one.
2. A `.tic` cart is binary, not plain text like Pico-8's `.p8`, so there's
   no safe hex-splice patch the way the Pico-8 tool does it directly. This
   tool writes a PNG (same hand-rolled zlib/struct writer as the Pico-8
   tool, still no third-party deps) and shells out to the local `tic80`
   binary's own `import tiles`/`import sprites` console command, which
   TIC-80 already merges to the nearest palette colour. `dump` is the
   mirror: it shells out to `export tiles`/`export sprites` to pull a
   whole bank back out as one PNG for review, rather than reimplementing
   the binary cart format to read it ourselves.

Palette note: the PALETTE table below is the Pico-8 hardware palette,
reused here as a placeholder reference for previewing def files before a
real cart exists. TIC-80's palette is remappable per-cart (see
../tic80.md's Lua dialect & API notes), and 4/tic-80/PLAN.md's Phase 0b
hasn't decided yet whether the TIC-80 build keeps these exact hues or
uses the remap room for something new — once that's locked, this table
may need to change to match whatever's actually poked into the cart's
palette RAM (VRAM offset 0x3FC0), or a --palette override may be worth
adding. Def files are still portable either way: they store palette
*indices*, not RGB, matching whichever concrete palette the cart uses.
"""
import argparse
import math
import os
import random
import shutil
import struct
import subprocess
import sys
import tempfile
import uuid
import zlib
from pathlib import Path


def maybe_open(path, do_open):
    """Launch the OS image viewer on a written preview, unless suppressed.

    Default-on: previews are for a human to look at, and a printed path
    nobody follows isn't a review step. --no-open opts out (scripting, CI).
    """
    if do_open and sys.platform == "darwin":
        subprocess.run(["open", str(path)], check=False)


def find_tic80():
    """Resolve the local tic80 binary: $TIC80 env var, then PATH (the
    interactive-shell alias tic80.md documents), then the documented local
    build path, in that order. Raises with a clear message if none work,
    since a silent fallback here would fail confusingly deep inside a
    subprocess call instead."""
    for candidate in (os.environ.get("TIC80"), "tic80",
                       str(Path.home() / "tools/TIC-80/build/bin/tic80")):
        if not candidate:
            continue
        found = candidate if Path(candidate).is_file() else shutil.which(candidate)
        if found:
            return found
    raise RuntimeError(
        "couldn't find a tic80 binary — set $TIC80, put tic80 on PATH, "
        "or confirm ~/tools/TIC-80/build/bin/tic80 exists (see ../tic80.md)"
    )


# Pico-8 hardware palette (RGB), indices 0-15 — placeholder reference until
# 4/tic-80/PLAN.md's Phase 0b locks the TIC-80 build's actual palette (see
# module docstring's Palette note).
PALETTE_NAMES = [
    "black", "dark blue", "dark purple", "dark green",
    "brown", "dark grey", "light grey", "white",
    "red", "orange", "yellow", "green",
    "teal", "dark red", "pink", "peach",
]
SYMBOLS = " #@%+=*o0xX&$~^:;"[:16]

PALETTE = [
    (0, 0, 0), (29, 43, 83), (126, 37, 83), (0, 135, 81),
    (171, 82, 54), (95, 87, 79), (194, 195, 199), (255, 241, 232),
    (255, 0, 77), (255, 163, 0), (255, 236, 39), (0, 228, 54),
    (41, 173, 255), (131, 118, 156), (255, 119, 168), (255, 204, 170),
]

BANKS = ("tiles", "sprites")


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
    """Render several sprite defs into one PNG, side by side with a grid
    line between them. This is local review of def files, unrelated to a
    bank's 8x8-slot layout — see `dump` for that."""
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


def cmd_ascii(args):
    """Print sprite(s) side by side as glyph grids, for fast terminal review."""
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
    grid = [[base] * 8 for _ in range(8)]
    c = accent if accent is not None else 0
    for y in range(8):
        for x in range(8):
            if (x + y) % spacing == 0 or (x - y) % spacing == 0:
                grid[y][x] = c
    return grid


def pat_cracks(rng, base, accent, segments=2, **kw):
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


def sprite_hex_rows(grid):
    return ["".join(f"{c:x}" for c in row) for row in grid]


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


def run_tic80(fs_dir, commands):
    """Run a chain of TIC-80 console commands against a cart's fs folder
    and return (stdout, stderr). load/import/export/save all return
    immediately — unlike `run`, which blocks the console forever waiting
    on the GUI event loop (confirmed directly; see 4/tic-80/PLAN.md's
    Phase 0a note). Never chain `run` into this.

    stdin=DEVNULL is defensive, not a confirmed fix for anything: an
    earlier version of this code hung and a single-trial test made
    inherited stdin look like the cause, but a proper A/B (6 clean runs
    with stdin inherited and the real bug — see save_cart's docstring —
    fixed; 3/3 hangs with stdin=DEVNULL and that real bug reintroduced)
    showed inherited stdin was never it. Left in anyway since it's free
    and stdin has no reason to matter to a batch of load/import/export/
    save commands; just don't repeat the earlier mistake of citing it as
    an explanation for a hang without re-testing the claim.
    """
    tic80 = find_tic80()
    cmd = [tic80, f"--fs={fs_dir}", "--cli", "--cmd", " & ".join(commands) + " & exit"]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30, stdin=subprocess.DEVNULL)
    return result.stdout, result.stderr


def slot_xy(index):
    """Pixel offset of sprite `index` (0-255) within its bank's 128x128
    sheet — 16 sprites per row, 8px each, same addressing Pico-8 uses for
    its one shared sheet."""
    if not 0 <= index <= 255:
        raise ValueError(f"sprite index must be 0-255, got {index}")
    return (index % 16) * 8, (index // 16) * 8


def prepare_import(fs_dir, sprite_path, bank, index):
    """Write one sprite def to a temp PNG inside the cart's fs folder and
    return (import command string, temp PNG Path). Caller runs the
    command (possibly batched with others) and always cleans up the temp
    file, success or failure."""
    grid = load_sprite(sprite_path)
    rgb_rows = [[PALETTE[c] for c in row] for row in grid]
    x, y = slot_xy(index)
    with tempfile.NamedTemporaryFile(suffix=".png", dir=fs_dir, delete=False) as tmp:
        tmp_path = Path(tmp.name)
    write_png(rgb_rows, tmp_path, scale=1)
    return f"import {bank} {tmp_path.name} x={x} y={y}", tmp_path


def save_cart(cart_path, extra_cmds, expect_imports=0):
    """Load a cart, run extra_cmds (import commands) against it, and save
    the result — all inside one TIC-80 process, so every import lands in
    the same in-memory cart before the single save at the end (a batch of
    N imports in N separate processes would each start from the
    on-disk cart and only the last save's import would ever persist).

    Saves to a fresh temp cart name in the same fs folder rather than
    `save <cart.name>` directly: TIC-80's `save` blocks on an
    "already exists, overwrite?" confirmation that never resolves in a
    non-interactive shell (confirmed directly, hangs indefinitely — see
    4/tic-80/PLAN.md's Phase 0a note), even though the cart being
    overwritten is the exact file `load` just read. Renaming the temp
    save over the real cart path afterward, from Python, sidesteps it.
    `export` doesn't have this problem (confirmed it silently overwrites),
    which is why `dump` below doesn't need this dance.

    The temp name is generated (uuid4, not tempfile.NamedTemporaryFile)
    and deliberately never created on disk before `save` runs: TIC-80's
    "already exists" check fires against ANY file already at that path,
    including an empty placeholder Python itself created to reserve a
    unique name — confirmed directly, that's what actually caused
    apparently-random hangs during development here, not a real TIC-80
    race. NamedTemporaryFile is exactly wrong for a save target for this
    reason (it creates the file as a side effect of reserving the name);
    it's still correct for the PNG import source in prepare_import,
    since that file needs to genuinely exist with real content by the
    time `import` reads it.
    """
    cart = Path(cart_path)
    tmp_name = f"tmp_{uuid.uuid4().hex}.tic"
    tmp_path = cart.parent / tmp_name
    try:
        cmds = [f"load {cart.name}", *extra_cmds, f"save {tmp_name}"]
        out, err = run_tic80(cart.parent, cmds)
        if out.count("imported") != expect_imports:
            raise RuntimeError(
                f"expected {expect_imports} import confirmation(s), got {out.count('imported')} "
                f"— stdout: {out!r} stderr: {err!r}"
            )
        if "saved" not in out or not tmp_path.exists():
            raise RuntimeError(f"save didn't confirm success — stdout: {out!r} stderr: {err!r}")
        tmp_path.replace(cart)
    finally:
        tmp_path.unlink(missing_ok=True)  # no-op once replace() has moved it


def cmd_patch(args):
    cart = Path(args.cart)
    import_cmd, tmp_png = prepare_import(cart.parent, args.sprite, args.bank, args.index)
    try:
        save_cart(cart, [import_cmd], expect_imports=1)
    finally:
        tmp_png.unlink(missing_ok=True)
    print(f"patched {args.bank} slot {args.index} into {cart}")


def cmd_patch_all(args):
    """Batch-patch many sprites from a manifest: `bank index path` per
    line, # comments allowed, blank lines ignored. One TIC-80 process,
    one save, regardless of manifest size — see save_cart's docstring."""
    cart = Path(args.cart)
    entries = []
    for lineno, raw in enumerate(Path(args.manifest).read_text().splitlines(), 1):
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        parts = line.split(None, 2)
        if len(parts) != 3 or parts[0] not in BANKS:
            raise ValueError(
                f"{args.manifest}:{lineno}: expected 'tiles|sprites index path', got {raw!r}"
            )
        bank, idx_str, sprite_path = parts
        entries.append((bank, int(idx_str), sprite_path.strip()))

    import_cmds, tmp_pngs = [], []
    try:
        for bank, index, sprite_path in entries:
            cmd, tmp_png = prepare_import(cart.parent, sprite_path, bank, index)
            import_cmds.append(cmd)
            tmp_pngs.append(tmp_png)
        save_cart(cart, import_cmds, expect_imports=len(entries))
    finally:
        for t in tmp_pngs:
            t.unlink(missing_ok=True)
    print(f"patched {len(entries)} sprites into {cart} from {args.manifest}")


def cmd_dump(args):
    """Export a whole bank (tiles or sprites) back out as one PNG, via
    TIC-80's own `export`, for visual review after patching — the TIC-80
    equivalent of eyeballing a cart's __gfx__ section directly, which
    isn't possible here since .tic is binary.

    Two things make this PNG look "wrong" at a glance that aren't bugs,
    confirmed by diffing raw pixel bytes against a pre-patch export
    rather than trusting a visual skim (which is what caught both):

    1. Colours won't match a def file's PALETTE table until Phase 0b
       locks the TIC-80 build's actual palette. Import nearest-matches
       your source RGB against *TIC-80's own* current palette, not
       Pico-8's, so a def written with Pico-8 red (index 8) can come
       back a different hue entirely until that's decided.
    2. This build's own PNG export writes palette-index-0 pixels as
       alpha=0 (RGBA colour type 6, transparent), a sheet-preview
       convention, not a rendering bug. A def with a black/index-0
       background can look almost entirely blank against a light
       viewer background as a result — it isn't; the pixels are there
       with alpha 0, confirmed via raw IDAT inspection."""
    cart = Path(args.cart)
    out = Path(args.out)
    cmds = [f"load {cart.name}", f"export {args.bank} {out.name}"]
    stdout, stderr = run_tic80(cart.parent, cmds)
    exported = cart.parent / out.name
    if not exported.exists():
        raise RuntimeError(f"export didn't produce a file — stdout: {stdout!r} stderr: {stderr!r}")
    if exported != out:
        exported.replace(out)
    print(f"wrote {out} ({args.bank} bank of {cart})")
    maybe_open(out, args.open)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    pv = sub.add_parser("preview", help="render a sprite def to a scaled-up PNG")
    pv.add_argument("sprite", help="path to an 8x8 hex-grid sprite file")
    pv.add_argument("out", help="output PNG path")
    pv.add_argument("--scale", type=int, default=32)
    pv.add_argument("--no-open", dest="open", action="store_false", help="don't launch the OS viewer")
    pv.set_defaults(func=cmd_preview)

    sh = sub.add_parser("sheet", help="render several sprite defs side by side into one PNG")
    sh.add_argument("sprites", nargs="+", help="two or more sprite files to lay out left to right")
    sh.add_argument("out", help="output PNG path")
    sh.add_argument("--scale", type=int, default=24)
    sh.add_argument("--no-open", dest="open", action="store_false", help="don't launch the OS viewer")
    sh.set_defaults(func=cmd_sheet)

    asc = sub.add_parser("ascii", help="print sprite(s) as glyph grids in the terminal")
    asc.add_argument("sprites", nargs="+", help="one or more sprite files to show side by side")
    asc.add_argument("--color", action="store_true", help="use ANSI truecolour blocks instead of glyphs")
    asc.set_defaults(func=cmd_ascii)

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

    pa = sub.add_parser("patch", help="write a sprite def into a cart's tiles/sprites bank")
    pa.add_argument("cart", help="path to the .tic cartridge file")
    pa.add_argument("sprite", help="path to an 8x8 hex-grid sprite file")
    pa.add_argument("bank", choices=BANKS, help="which bank to patch")
    pa.add_argument("index", type=int, help="slot within that bank, 0-255")
    pa.set_defaults(func=cmd_patch)

    pall = sub.add_parser("patch-all", help="batch-patch many sprites into a cart from a manifest")
    pall.add_argument("cart", help="path to the .tic cartridge file")
    pall.add_argument("manifest", help="text file of 'tiles|sprites index path' lines, # comments allowed")
    pall.set_defaults(func=cmd_patch_all)

    dm = sub.add_parser("dump", help="export a cart's whole tiles/sprites bank to one PNG for review")
    dm.add_argument("cart", help="path to the .tic cartridge file")
    dm.add_argument("bank", choices=BANKS, help="which bank to export")
    dm.add_argument("out", help="output PNG path")
    dm.add_argument("--no-open", dest="open", action="store_false", help="don't launch the OS viewer")
    dm.set_defaults(func=cmd_dump)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    sys.exit(main())
