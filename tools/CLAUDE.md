# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

`maps/`, `music/`, and `shared/` are still placeholder directories with no scripts yet. `sprites/` has a working tool: `sprites/sprite_tool.py` (preview, sheet, ascii, patch subcommands) and `sprites/defs/` (hex-grid sprite source files). `sfx/` also has a working tool now: `sfx/sfx_tool.py` (encode, decode, patch, patch-all, selftest subcommands), `sfx/defs/` (human-readable note-sequence source files), and `sfx/manifests/`. `export/` has one tool, `export/strip_comments.py` (see [Export capacity vs. token limit](#export-capacity-vs-token-limit)), that `preview/generate.py` calls automatically before every `pico8 -export` run; it isn't an asset-generation tool like the others, it operates on a whole `.p8` cart rather than producing one section's data. Check [TASKS.md](TASKS.md) for the current backlog before starting work on the other asset types.

There is no build, lint, or test tooling. Nothing exists to run yet, and none of the commands in [Usage pattern](#usage-pattern) below correspond to real files — they illustrate the intended CLI shape for scripts you write here.

Asset generation utilities for Pico-8 game development. These are host-side scripts (Python, shell, or Node) that run on the developer's machine to produce content that gets pasted into `.p8` cartridges.

## Purpose

Generating Pico-8 assets by hand is slow and error-prone. This project provides scripts that automate:

- **Sprites** — output Pico-8 sprite sheet data (`__gfx__` section) from source images or parameterised generators
- **Maps** — output `__map__` section data from tilemaps, CSV layouts, or procedural descriptions
- **SFX** — output `__sfx__` section data from descriptions or MIDI-style input
- **Music** — output `__music__` section patterns from sequences of SFX slot references

## Folder layout

```
tools/
  sprites/    scripts that produce __gfx__ hex data
  maps/       scripts that produce __map__ hex data
  sfx/        scripts that produce __sfx__ entries
  music/      scripts that produce __music__ patterns
  shared/     utility functions used across generators (palette mapping, hex encoding, etc.)
  export/     strips __lua__ comments into a build-artifact cart copy, for pico8's export path
```

## Output format

Each script should write its output section to stdout so it can be inspected and then pasted into the relevant section of a `.p8` file. A script may also accept a `--cart` flag to patch the section directly into a named cartridge file.

Pico-8 section delimiters:

```
__gfx__
__map__
__sfx__
__music__
```

**Section order matters when hand-editing a `.p8` file.** Pico-8's own canonical order is `__lua__`, `__gfx__`, `__label__`, `__map__`, `__sfx__`, `__music__` (confirmed against games 3 and 4's carts). If a section is appended in the wrong slot — game 5's `__sfx__` was once appended directly after `__gfx__`, skipping `__label__` — Pico-8 tolerates it on load but **silently drops it on the next save** (e.g. when the cart is opened and saved from the editor, or possibly on `-run` under some circumstances): it inserts its own default `__label__` where one was missing and doesn't carry forward whatever followed in the "wrong" position. Always append new sections after whatever sections already exist in the cart, in the canonical order above, not just at the end of the file. If a section you added disappears after the cart's been opened in Pico-8, check this first before assuming a content/encoding bug.

## Export capacity vs. token limit

Pico-8 enforces two independent size limits, and only one of them is what a game's CLAUDE.md/PLAN.md token-count tracking sees:

- **Token limit (8,192)**: real code tokens only, comments excluded. This is the number every game folder's Status section tracks.
- **Export capacity**: when Pico-8 packs a cart for `.p8.png` or a `-export` build, it compresses the raw `__lua__` text, comments included, into a fixed-size slot separate from the token limit (roughly 15.6 KB compressed on the classic cart format). A cart can sit comfortably under the token cap and still fail export with `failed: code block too large` if its comments are heavy enough to blow that byte budget.

Game 6 hit this first: 4,357/8,192 tokens, but comments made up 65% of its `__lua__` source bytes (a documentary style shared with this project's own CLAUDE.md files), which pushed compressed size past the cap. `export/strip_comments.py` fixes this without touching the real source: it writes a comment-stripped copy of a cart for export only, leaving the fully-commented dev cart (and the bug-history its comments record) untouched. `preview/generate.py` calls it automatically; run it by hand (`python3 export/strip_comments.py <cart>.p8`) to check a cart's export headroom before running Pico-8 directly. `--selftest` verifies the comment-scanner against strings/long-strings/nested brackets by actually running Lua before and after and diffing output.

## Pico-8 data formats

### Sprite sheet (`__gfx__`)
- 128×128 pixel canvas, 16 colours, 4 bits per pixel
- Each row is 128 nibbles (64 bytes) of hex, low nibble = left pixel
- 128 rows total
- Colour indices: 0–15 (Pico-8 palette)

### Map (`__map__`)
- 128×64 cells (upper half only; lower 32 rows overlap sprite sheet)
- Each row is 128 bytes of hex, each byte = sprite index (0–255)
- 64 rows total

### SFX (`__sfx__`)
- 64 slots, each slot is one line
- Format: `spd xxx noisedata...` — see Pico-8 manual for full encoding
- Each note is 5 hex chars: pitch (2), waveform (1), volume (1), effect (1)
- 32 notes per slot

### Music (`__music__`)
- 64 patterns, each is one line
- Format: `flags c0 c1 c2 c3` where flags is 2 hex chars, each channel is an SFX slot (2 hex chars)

## Palette reference

```
0  black       1  dark blue    2  dark purple  3  dark green
4  brown       5  dark grey    6  light grey   7  white
8  red         9  orange       10 yellow       11 green
12 teal        13 dark red     14 pink         15 peach
```

For Atari 2600-style palette: use 0, 7, 8, 9, 10, 11, 3, 12, 6, 5, 2, 13.

## Previewing generated output

Any tool in this project that produces a visual preview artifact (a PNG, currently only `sprites/sprite_tool.py`'s `preview` and `sheet` subcommands; the same should apply to `maps/` renders and any future visual output) MUST launch the OS image viewer on it by default, via `open <path>` on macOS. A printed file path nobody follows isn't a review step.

- Default to opening; provide a `--no-open` flag for scripting/CI use, don't require an opt-in flag for the common case
- Write preview PNGs to the session scratchpad directory when working in Claude Code, not `/tmp`
- When comparing multiple sprites/tiles/frames, prefer a single combined image (see `sheet`) over one image per item; fewer viewer windows, easier side-by-side comparison
- This applies regardless of which asset type the tool covers; it's a project-wide convention, not specific to sprites

## Constraints

- Scripts MUST be runnable without installation beyond a standard Python 3.x environment, or note dependencies clearly at the top of the file
- Output must be valid Pico-8 section data — test by pasting into a cartridge and loading it
- No GUI tools; everything is CLI
- Scripts should be idempotent: running twice with the same input produces the same output

## Usage pattern

Illustrative only, no scripts implementing this exist yet:

```sh
# Generate sprite data and inspect
python sprites/player.py

# Patch directly into a cartridge
python sprites/player.py --cart ../1/1.p8

# Generate SFX for a named event
python sfx/events.py --event trap
```

## Related projects

- `../SPEC-FORMAT.md` — the document set and section structure every game folder follows (README, DESIGN, PLAN, CLAUDE); DESIGN.md's Palette section is what this project's `sprites/` and `shared/` scripts should ultimately help fill in
- `../1/` — the first Pico-8 game built with these tools (a maze game); its `1.p8` is a reference cartridge and `1/CLAUDE.md` documents its architecture
- `../lib/` — shared Lua snippets pasted into cartridges' `__lua__` section; separate from this project's host-side generation scripts
