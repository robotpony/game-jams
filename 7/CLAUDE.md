# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "7 Perfect War" — a two-player hex-based WWII combined-arms wargame (human vs. human, or human vs. AI) won by accumulating Victory Points from controlling towns, not by destroying enemy units. The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: not yet built.** README.md, DESIGN.md, and PLAN.md exist; the `.p8` cart itself hasn't been started. A design conversation trimmed the README's full rules (11 unit types, 11 terrain types, full raycast LOS, transport, a 5-option rules menu) down to a scope that can plausibly fit ~8,192 tokens alongside a two-role AI opponent: a 5-unit roster, 6 terrain types, simplified LOS, fixed rules defaults, and greedy-heuristic-only AI. See [DESIGN.md](DESIGN.md) for the full scope decisions and first-pass numbers, and [PLAN.md](PLAN.md) for the build order (rules engine first, verified via 2-player Hotseat, AI added afterward). This is still by far the most rules-dense entry in the jam so far; DESIGN.md's Token budget section has a specific fallback cut order for if a token check runs hot mid-build.

## Development

Pico-8 has no build system, package manager, linter, or test runner. The workflow is:

- Edit the `.p8` file in an external editor or inside Pico-8's built-in editor
- Run with `pico8 -run 7.p8` (requires Pico-8 installed)
- Or open Pico-8, then `load 7.p8` and press Ctrl+R to run

Verification is manual: load the cart and play it.

## Pico-8 constraints

These constraints shape every implementation decision:

- **Token limit**: ~8,192 tokens total; code is compressed and must be counted aggressively
- **Display**: 128×128 pixels, 16-colour palette
- **Sprites**: 8×8 pixels each, 256 slots in the sprite sheet
- **Map**: 128×64 cells, shared memory with the bottom half of the sprite sheet
- **Sound**: 64 SFX slots, 4 channels
- **Lua variant**: Pico-8 Lua omits parts of the standard library; no `string.format`, use `tostr()`, `tonum()`, `sub()`, `#str`, `add()` for tables

A hex-based wargame with two-player buy-point armies, LOS/spotting, and delayed indirect fire is a lot of rules to fit in ~8,192 tokens; lean hard on `lib/` for anything generic (state machine, HUD, input, seeded RNG) rather than rederiving it, and expect the hex grid math and unit/LOS tables to eat most of the remaining budget.

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for shared Lua snippets (input handling, screen flash/fade, state machine, tweening, collision, HUD, map queries, seeded RNG) before writing new utility code from scratch.
