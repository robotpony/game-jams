# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "5 To The Top" — a vertical platform puzzler, a wild-west-themed side-view re-imagining of early-80s climbing games (Donkey Kong and its era), built for the "Warped 2026 Game Jam". The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: Phase 1 of 7 implemented.** `5.p8` covers PLAN.md's Phase 1: procedural row/tile generation (4 rows × 16 columns, chute lane, gap-density roll, one guaranteed ladder-or-box connector per row pair), rendering the 4 platform rows plus the fixed ground row, and player movement (walk, jump with gravity, ladder climbing, stairs/box stepping). No title/end screens, HUD, hazards, rope, gun, or bottles yet — those land in Phases 2-6. `gen_level()`'s connector logic was checked with a 2,000-trial Lua harness (chute always gap in all rows, every connector solid on both sides, no connector on the chute column); it does not check row-to-row horizontal walkability past gap tiles, which is Phase 1's remaining manual verify step (see [DESIGN.md](DESIGN.md)'s Level generation note and [PLAN.md](PLAN.md)'s Phase 1 checklist). [DESIGN.md](DESIGN.md) is still the source of truth for phases not yet built; once the cart is complete this file's Architecture section replaces it entirely per `SPEC-FORMAT.md`'s document lifecycle.

## Development

Pico-8 has no build system, package manager, linter, or test runner. The workflow is:

- Edit the `.p8` file in an external editor or inside Pico-8's built-in editor
- Run with `pico8 -run 5.p8` (requires Pico-8 installed)
- Or open Pico-8, then `load 5.p8` and press Ctrl+R to run

Verification is manual: load the cart and play it.

## Pico-8 Constraints

These constraints shape every implementation decision:

- **Token limit**: ~8,192 tokens total; code is compressed and must be counted aggressively
- **Display**: 128×128 pixels, 16-colour palette
- **Sprites**: 8×8 pixels each, 256 slots in the sprite sheet
- **Map**: 128×64 cells, shared memory with the bottom half of the sprite sheet
- **Sound**: 64 SFX slots, 4 channels
- **Lua variant**: Pico-8 Lua omits parts of the standard library; no `string.format`, use `tostr()`, `tonum()`, `sub()`, `#str`, `add()` for tables

This game is the most system-dense in the jam so far (ramp/tile generation, rolling hazard AI, pendulum rope physics, a timed weapon, two-tier item system); see [DESIGN.md](DESIGN.md)'s Token budget note before starting implementation.

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for shared Lua snippets (input handling, screen flash/fade, state machine, tweening, collision, HUD, map queries, seeded RNG) before writing new utility code from scratch. Only the shared title card (`title.lua`) and screen-flash (`screen.lua`) helpers exist there today; the ramp/tile/hazard/rope logic this game needs is novel and isn't in `lib/` yet — write it in the cart, and consider promoting it to `lib/` afterward if it'd help a future game.
