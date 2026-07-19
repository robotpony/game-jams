# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "Gyri #4" — an arcade shooter with Atari 2600 aesthetics, Space Invaders/Galaga-style but with the player's and enemies' straight lines replaced by concentric arcs. The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: Phase 1 of 8 implemented.** `4.p8` exists but only covers PLAN.md's Phase 1 (ship arc movement, hold-to-fire shooting), with placeholder visuals (a filled circle for the ship, single pixels for shots) rather than real sprites, which land in Phase 7. Phase 1's manual play-test verify step hasn't been run yet. The arc's orientation was corrected after Phase 1 was first built (it had been a downward-opening dome instead of an upward-opening valley — see DESIGN.md's Arc geometry note), and `4.p8`'s constants and shot direction were updated to match. After that fix, the arc's vertical placement was still off: with the shared centre at `(64,25)`, the ship's resting position landed at `y=89`, which read as vertically centred on-screen with a large unused gap down to the HUD. The shared centre moved to `(64,55)` so the ship's resting position sits at `y=119`, just above the HUD line, with every enemy-arc and grid-adjacent y-value in DESIGN.md's Screen layout sketch and Core system design table shifted by the same +30px (radii, angles, and trim math are all unaffected, since they don't depend on `cy`); a placeholder HUD line (`line(0,120,127,120,7)`) was also added to `4.p8` so this reads correctly during play-testing ahead of Phase 6's real HUD. PLAN.md's Phase 1 checklist still holds, but treat it as re-verify-needed rather than already-confirmed. Design for all 8 phases is locked, see README.md and [DESIGN.md](DESIGN.md) for exact numbers; DESIGN.md remains the source of truth until more phases land and this file grows a full Architecture section the way [`../3/CLAUDE.md`](../3/CLAUDE.md) documents game 3.

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

- Ship holds an angular position on a fixed-radius arc near the bottom of the screen instead of an x-coordinate; left/right input sweeps that angle, clamped to ±69°
- Hold-to-fire: shots repeat every 4 frames while held, along the radius line through the ship's current angle, so shot direction changes with the ship's position on the arc
- Enemies live on three concentric arcs at *smaller* radii than the ship's own (53/43/33px vs the ship's 64px) — the shared centre sits above the ship, so a smaller radius is what puts an arc higher on screen, not a larger one
- Enemies fire back radially *outward* (away from the shared centre, hence down toward the ship, the opposite direction from the player's own inward shots) on a wave-scaled cooldown, and occasionally dive at the ship; a total enemy+enemy-shot cap of 32 bounds concurrent entities
- A diving enemy that misses never leaves the wave: it respawns at the outer edge of its arc's angular band (its highest reachable point, not its centred position) and comes back faster and more aggressive (a per-enemy miss counter, capped after ~7 misses). A wave clears only by killing every enemy on it, never by attrition
- Ship, enemy, and shot sprites are distinct pixel art (not palette swaps of each other); shots share 3 sprites (straight/shallow/steep) mirrored via `flip_x`/`flip_y` to cover every reachable travel direction; outer-tier enemies render larger via `sspr` scaling instead of a separate sprite
- A wave clears when every enemy on it is destroyed; the run is endless, with enemy count, speed, and aggression all scaling with wave number (formulas in DESIGN.md)
- Ship colour is fixed (white) and never re-tints; every other colour (enemies, shots, background grid) rotates through a 4-wave theme cycle, defined in DESIGN.md's Palette section
- All values are decided; DESIGN.md is the source of truth for exact numbers, don't re-derive or re-guess them during implementation

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for shared Lua snippets (input handling, screen flash/fade, state machine, tweening, collision, HUD, map queries, seeded RNG) before writing new utility code from scratch. Snippets are copy-pasted into this cart's `__lua__` section, not imported — inline only what's needed given the shared token budget.
