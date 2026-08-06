# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Entries for the "Warped 2026 Summer Game Jam" (see [README.md](README.md)): 4 weeks, minimum 2 games per week, across pico-8 (2 weeks), picotron (1 week), and pygame (1 week). Each numbered folder (`1/`, `2/`, `3/`, ...) is one self-contained game entry, documented per [`SPEC-FORMAT.md`](SPEC-FORMAT.md).

## Repository layout

```
SPEC-FORMAT.md    the document set and section structure every game folder follows
PLATFORMS.md      constraints/capabilities reference for each platform a game can target
BUGS.md           cross-game bug tracker, implementation bugs found by reading cart source
1/, 2/, 3/, ...   one folder per game entry, numbered in build order
lib/              shared Lua snippets, copied into pico-8 carts (own CLAUDE.md)
tools/            host-side scripts that generate pico-8 asset data (own CLAUDE.md)
preview/          static page that showcases all game entries (own README)
```

Always check a subfolder's own `CLAUDE.md` before working in it; it has the game- or tool-specific architecture. This root file only covers what's shared across the whole repo.

## Per-game document flow

Each game folder follows the document set and section structure defined in [`SPEC-FORMAT.md`](SPEC-FORMAT.md): `README.md` (spec), `DESIGN.md` (pre-implementation technical design), `PLAN.md` (phased checklist), `CLAUDE.md` (constraints, then as-built architecture once the cart exists). Read that file before creating or restructuring any of them; don't restate its rules here.

Where a game hasn't reached a stage yet, its `CLAUDE.md` says so explicitly (e.g. `2/CLAUDE.md` currently notes "not yet built"). When you finish implementing a cart, update that game's `CLAUDE.md` to match — don't leave it describing the pre-build design once code exists.

Every game folder uses uppercase `CLAUDE.md` / `README.md`, including `1/`, which was renamed from lowercase `claude.md` / `readme.md` to match.

## Commands

There is no build system, package manager, linter, or test runner anywhere in this repo — Pico-8 carts don't have one, and `tools/` and `preview/` don't have one yet either.

Run a game cart:

```sh
pico8 -run <N>/<N>.p8   # e.g. pico8 -run 1/1.p8
```

Or inside Pico-8: `load <N>/<N>.p8` then Ctrl+R.

Verification for a game is always manual: load the cart and play it. `PLAN.md` files mark which checklist items still need a manual play-test.

`1/backup/`, `1/bbs/`, `1/carts/`, `1/cdata/`, `1/cstore/`, `1/plates/` are empty directories Pico-8 itself manages (its BBS/backup/cart-data folders), not project source; ignore them.

## Pico-8 constraints (games)

Every game in the jam so far targets Pico-8, so these shape every implementation decision in a game folder unless that game's CLAUDE.md says otherwise. Building on Picotron, Pygame, or TIC-80 instead — for an upscale, see [`PLATFORMS.md`](PLATFORMS.md) for that platform's equivalents and [`SPEC-FORMAT.md`](SPEC-FORMAT.md#platforms-and-folder-layout) for how its files are organized.

- Token limit ~8,192 per cart; code is compressed and must be counted aggressively
- Display: 128×128 pixels, 16-colour palette
- Sprites: 8×8 pixels each, 256 slots in the sprite sheet
- Map: 128×64 cells, shares memory with the bottom half of the sprite sheet
- Sound: 64 SFX slots, 4 channels
- Lua variant omits parts of the standard library: no `string.format`; use `tostr()`, `tonum()`, `sub()`, `#str`, `add()` for tables

Games target an Atari 2600 / Intellivision-style aesthetic approximated through Pico-8's native 16-colour palette (see individual game `CLAUDE.md`/`DESIGN.md` files for their specific palette mapping).

## Shared code vs. shared tools

Don't confuse `lib/` and `tools/`:

- `lib/` is Lua source, copied into a cart's `__lua__` section at write time (no include mechanism; Pico-8 has no module system). Check here before writing new gameplay utility code (state machines, tweening, collision, HUD, input, seeded RNG).
- `tools/` is host-side scripts (Python/shell/Node, run on the dev machine) that generate `__gfx__`/`__map__`/`__sfx__`/`__music__` section data to paste into a cart. It's currently an empty scaffold; see [tools/TASKS.md](tools/TASKS.md) for the planned first scripts.

Both a game's token budget (in `lib/`) and its section data format (in `tools/`) are governed by Pico-8's own limits, documented in each folder's `CLAUDE.md`.
