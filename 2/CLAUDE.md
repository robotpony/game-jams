# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "2 Mission" — an action/platform/puzzle game with Atari 2600 aesthetics, a vastly simplified remake of Impossible Mission (Epyx, 1984). The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: not yet built.** No `.p8` cartridge exists in this folder yet, and several spec details are still open (see README's Open questions). Implementation should follow README.md and [DESIGN.md](DESIGN.md); once a `2.p8` cart exists, this file should be expanded with the actual architecture (state variables, game states, tile/sprite IDs, SFX slots) the way [`../1/CLAUDE.md`](../1/CLAUDE.md) documents game 1.

## Development

Pico-8 has no build system, package manager, linter, or test runner. The workflow is:

- Edit the `.p8` file in an external editor or inside Pico-8's built-in editor
- Run with `pico8 -run 2.p8` (requires Pico-8 installed)
- Or open Pico-8, then `load 2.p8` and press Ctrl+R to run

Verification is manual: load the cart and play it.

## Pico-8 Constraints

These constraints shape every implementation decision:

- **Token limit**: ~8,192 tokens total; code is compressed and must be counted aggressively
- **Display**: 128×128 pixels, 16-colour palette
- **Sprites**: 8×8 pixels each, 256 slots in the sprite sheet
- **Map**: 128×64 cells, shared memory with the bottom half of the sprite sheet
- **Sound**: 64 SFX slots, 4 channels
- **Lua variant**: Pico-8 Lua omits parts of the standard library; no `string.format`, use `tostr()`, `tonum()`, `sub()`, `#str`, `add()` for tables

## Design summary (from README.md and DESIGN.md)

- Player rides an elevator between randomized floors, then explores corridor-linked puzzle rooms (3 floors, centre lift, robots, searchable objects)
- Robots have 3 behaviour patterns: stationary-look, patrol, chase (see DESIGN.md's Core system design)
- Searching an object fills a 10-step progress bar (~1s/step) and yields health or a puzzle letter; 10 letters total spell a secret word
- Win: reach the control room with the puzzle solved. Loss: timer reaches 0, or HP reaches 0
- Several values (health pickup amount, robot/fall damage, timer start, palette, some SFX) aren't decided yet; don't invent them when implementing — check README's Open questions first

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for shared Lua snippets (input handling, screen flash/fade, state machine, tweening, collision, HUD, map queries, seeded RNG) before writing new utility code from scratch. Snippets are copy-pasted into this cart's `__lua__` section, not imported — inline only what's needed given the shared token budget.
