# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "6 Land of Simplex" — a procedurally generated top-down cave-mining RPG with crafting and combat. The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: not yet built.**

Unlike games 1-5, this game doesn't use the Atari-2600-via-Pico-8 aesthetic. It uses Pico-8's real colour names directly, matched semantically to what each thing is (gold is yellow, water is blue); blocks share a family base colour plus a semantic accent and pattern rather than a unique hue per block, since Pico-8's 16 colours are shared by everything on screen at once. See README.md's Tile / sprite visuals section and DESIGN.md's Palette table for the full breakdown.

## Development

Pico-8 has no build system, package manager, linter, or test runner. The workflow is:

- Edit the `.p8` file in an external editor or inside Pico-8's built-in editor
- Run with `pico8 -run 6.p8` (requires Pico-8 installed)
- Or open Pico-8, then `load 6.p8` and press Ctrl+R to run

Verification is manual: load the cart and play it.

## Pico-8 Constraints

These constraints shape every implementation decision:

- **Token limit**: ~8,192 tokens total; code is compressed and must be counted aggressively
- **Display**: 128×128 pixels, 16-colour palette
- **Sprites**: 8×8 pixels each, 256 slots in the sprite sheet
- **Map**: 128×64 cells, shared memory with the bottom half of the sprite sheet
- **Sound**: 64 SFX slots, 4 channels
- **Lua variant**: Pico-8 Lua omits parts of the standard library; no `string.format`, use `tostr()`, `tonum()`, `sub()`, `#str`, `add()` for tables

This is the most system-dense game in the jam so far: procedural cave generation, 16 block types, 6 monster types with distinct AI, an 8-type inventory plus 2 equip slots, 8 crafting recipes, chests with a loot table, a visibility/fog system, and a help-overlay reference screen, all inside the same ~8,192-token budget. See [DESIGN.md](DESIGN.md)'s Token budget note before starting implementation — expect real trimming to be necessary, not just retuning. `lib/` doesn't yet cover most of what this game needs (only `screen.lua`, `title.lua`, `math.lua` exist); PLAN.md's Phase 0 builds the missing state machine, collision, map-query, and RNG primitives first, and their token cost still counts against this game's budget.

## Design summary (from README.md and DESIGN.md)

- Top-down; one large cave generated once at game start from Simplex noise (or a token-feasible approximation), stored in Pico-8's native map, camera scrolls and follows the player (reusing games 2/5's clamped-camera pattern) rather than a streaming/infinite world
- 16 destructible block types across 3 tool-gated tiers, plus 2 hazard blocks (Lava, Deep Water) and 2 special blocks (Treasure Vein, Glowstone); each mineable block has a resistance threshold (minimum tool tier to make any progress) and an HP pool (chipped away once met)
- Player moves 8-directionally, mines with an equipped tool, fights with an equipped weapon (swing + timed parry, no shield), 2 dedicated equip slots separate from 8 general inventory item types (3 tool tiers, 3 weapon tiers, a Lantern, a Health Potion)
- Visibility is a radius around the player; Glowstone and the Lantern extend it
- 6 monster types (melee and ranged mixed, easy to hard), each with a unique drop; combat drops feed weapon crafting, mining drops feed tool crafting
- Crafting is a flat recipe lookup, done from the Inventory overlay anywhere, no crafting station
- Chests are a separate world object (not a block), instant-open loot containers; rarely contain a Book, a special persistent item (outside the 8 general types, like coins) that unlocks a re-readable Help overlay (controls plus a tool-tier/block-tier and monster-drop/recipe reference)
- Difficulty is spatial, not time-based: block tier and monster difficulty both scale with distance from the player's spawn point
- No win condition; the run ends when player HP reaches 0
- Several details are still open (exact noise algorithm, Ancient Stone's purpose, exact tuning numbers, per-item stack limits, sound events, light-radius stacking, and the fog dither's token cost) — see README.md's Open Questions. Don't guess at these during implementation; resolve them first or ask

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) before writing new utility code from scratch, but don't assume it's all there: only `title.lua`, `screen.lua`, and `math.lua` are actually built. `state.lua`, `collision.lua`, `map.lua`, `rng.lua`, `input.lua`, and `hud.lua` are still backlog (see [`../lib/PLAN.md`](../lib/PLAN.md)), and this game needs most of them, hence PLAN.md's Phase 0. Games 2 and 5's scrolling-camera code and game 2's help-overlay pattern are the closest existing precedent for this game's camera and Help screen, but both need generalizing, not straight reuse: game 2/5's cameras clamp one axis only, this game needs both x and y; game 2's help overlay never needs to remember which state opened it, this game's does (openable from Playing or Inventory). World generation, mining, combat, inventory/crafting, and chest logic are all novel to this game and aren't in `lib/` yet.
