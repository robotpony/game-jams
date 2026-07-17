# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status

This is an empty scaffold: `sprites/`, `maps/`, `sfx/`, `music/`, and `shared/` exist as placeholder directories with no scripts yet. Check [TASKS.md](TASKS.md) for the current backlog before starting work; it lists the first three tools to build (a Pico-8 spec template, an SFX notation utility, and a `/pico8` skill).

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

- `../1/` — the first Pico-8 game built with these tools (a maze game); its `1.p8` is a reference cartridge and `1/claude.md` documents its architecture
- `../lib/` — shared Lua snippets pasted into cartridges' `__lua__` section; separate from this project's host-side generation scripts
