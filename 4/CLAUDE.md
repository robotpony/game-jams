# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "Gyri #4" — an arcade shooter with Atari 2600 aesthetics, Space Invaders/Galaga-style but with the player's and enemies' straight lines replaced by concentric arcs. The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: not yet built.** No `.p8` cartridge exists in this folder yet, and several spec details are still open (see README's Open questions). Implementation should follow README.md and [DESIGN.md](DESIGN.md); once a `4.p8` cart exists, this file should be expanded with the actual architecture (state variables, game states, tile/sprite IDs, SFX slots) the way [`../3/CLAUDE.md`](../3/CLAUDE.md) documents game 3.

## Development

Pico-8 has no build system, package manager, linter, or test runner. The workflow is:

- Edit the `.p8` file in an external editor or inside Pico-8's built-in editor
- Run with `pico8 -run 4.p8` (requires Pico-8 installed)
- Or open Pico-8, then `load 4.p8` and press Ctrl+R to run

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

- Ship holds an angular position on a fixed-radius arc near the bottom of the screen instead of an x-coordinate; left/right input sweeps that angle
- Shots fire along the radius line through the ship's current angle, so shot direction changes with the ship's position on the arc
- Enemies live on their own concentric arcs at smaller radii, closer to the implied off-screen centre, and sweep along them
- A wave clears when every enemy on it is destroyed; wave-to-wave difficulty scaling isn't decided yet
- Several values (arc geometry, enemy count/behaviour, lives, fire rate, scoring, palette, sound) aren't decided yet; don't invent them when implementing, check README's Open questions first

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for shared Lua snippets (input handling, screen flash/fade, state machine, tweening, collision, HUD, map queries, seeded RNG) before writing new utility code from scratch. Snippets are copy-pasted into this cart's `__lua__` section, not imported — inline only what's needed given the shared token budget.
