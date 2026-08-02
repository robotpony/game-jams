# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "6 Dug, Dug, Down." — a procedurally generated top-down cave-mining RPG with crafting and combat. The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: PLAN.md Phase 0 (shared `lib/` prerequisites) and Phase 1 (world generation & camera) built in `6.p8`. Phases 2-8 (mining, combat, inventory/crafting, chests, screens/state machine, visuals/sound, token check) not yet built.** DESIGN.md remains the authoritative pre-implementation design for everything past Phase 1; only World generation and the camera are documented as-built below, per SPEC-FORMAT.md's document lifecycle note — this isn't game 2's deliberate parallel-tracking exception, just a partial build where most systems genuinely haven't been written yet.

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

This is the most system-dense game in the jam so far: procedural cave generation, 16 block types, 6 monster types with distinct AI, an 8-type inventory plus 2 equip slots, 8 crafting recipes, chests with a loot table, a visibility/fog system, and a help-overlay reference screen, all inside the same ~8,192-token budget. See [DESIGN.md](DESIGN.md)'s Token budget note before starting implementation — expect real trimming to be necessary, not just retuning. PLAN.md's Phase 0 is complete: `lib/state.lua`, `collision.lua`, `map.lua`, `rng.lua`, `input.lua`, and `hud.lua` are now built (syntax-checked, not yet exercised in a real cart); their token cost still counts against this game's budget once pasted in.

## Design summary (from README.md and DESIGN.md)

- Top-down; one large cave generated once at game start via cellular automata (floor/wall shape) plus a distance-biased weighted roll per wall cell (block type), stored in Pico-8's native map, camera scrolls and follows the player (generalizing games 2/5's one-axis clamped-camera pattern to two axes) rather than a streaming/infinite world
- 16 destructible block types across 3 tool-gated tiers, plus 2 hazard blocks (Lava, Deep Water) and 2 special blocks (Treasure Vein, Glowstone); each mineable block has a resistance threshold (minimum tool tier to make any progress) and an HP pool (chipped away once met)
- Player moves 8-directionally, mines with an equipped tool, fights with an equipped weapon (swing + timed parry, no shield), 2 dedicated equip slots separate from 8 general inventory item types (3 tool tiers, 3 weapon tiers, a Lantern, a Health Potion); a 4th tool/weapon tier (Runic Pick/Blade, crafted from Ancient Stone) sits outside the 8 types like the Book and auto-equips on craft
- Visibility is a radius around the player; Glowstone and the Lantern extend it
- 6 monster types (melee and ranged mixed, easy to hard), each with a unique drop; combat drops feed weapon crafting, mining drops feed tool crafting
- Crafting is a flat recipe lookup, done from the Inventory overlay anywhere, no crafting station
- Chests are a separate world object (not a block), instant-open loot containers; rarely contain a Book, a special persistent item (outside the 8 general types, like coins) that unlocks a re-readable Help overlay (controls plus a tool-tier/block-tier and monster-drop/recipe reference)
- Difficulty is spatial, not time-based: block tier and monster difficulty both scale with distance from the player's spawn point
- No win condition; the run ends when player HP reaches 0
- Several details are still open (exact tuning numbers and the fog dither's token cost) — see README.md's Open Questions. Both are deliberately deferred to playtesting/measurement once more of the cart exists, not blocked on a decision; don't guess at them early, and don't try to force an answer before there's something to tune against

## Architecture

What's actually in `6.p8` right now (Phase 0 + Phase 1 only; everything else below this line in the file doesn't exist yet):

- **World storage**: Pico-8's native map (128×64 cells, `w`/`h` globals), one cell = one byte via `mget`/`mset`. Cell value `0` means floor (walkable); `1`-`16` is a wall block id, in the same order as README's block tier table (1-4 tier 1, 5-8 tier 2, 9-12 tier 3, 13-14 hazard, 15-16 special). No `__map__` section is baked into the cart file; the map starts blank and `gen_world()` populates it at `_init()` time.
- **`gen_world()`**: two passes, matching DESIGN.md's World generation. Pass 1 seed-fills each cell wall at 45%, then runs 4 cellular-automata smoothing iterations using `lib/map.lua`'s `neighbour()` (8-directional Moore count), **double-buffered** into a scratch `buf` table and copied back to the live map only after each full iteration finishes scanning, with a tie-preserving 3-way rule (`wc>4` stays/becomes wall, `wc<4` becomes floor, `wc==4` keeps the current value). An earlier in-place, 2-branch version (no `buf`, `wc>=5`) shipped first and broke badly: the first playtest showed an almost-empty field, traced to wall density cascading from ~44% seed fill down to ~3% within 4 iterations, because later cells in each scan read already-updated neighbours from earlier in the same pass. Confirmed both the bug and the fix by reproducing the exact algorithm outside Pico-8 with plain `lua` before touching the cart (see PLAN.md Phase 1's note) — the fixed version settles around ~30-40% wall density, checked with a temporary `printh()` diagnostic in real Pico-8, not by eyeballing. Out-of-bounds neighbours count as wall, which naturally seals the map edges. No connectivity guarantee: an isolated floor pocket is possible but not unreachable, since walls are minable (Phase 2). Pass 2 assigns every remaining wall cell a block id via `pick_block()`.
- **`find_spawn()`**: up to 50 random tries within a margin box (`cx` 10-117, `cy` 6-57) for a floor cell; falls back to force-clearing a small cross-shaped pocket near map centre if none land on floor. Sets the `spx`/`spy` globals DESIGN.md's Spawn placement note calls for (randomized each run, Euclidean-distance reference point).
- **`pick_block(cx,cy)`**: a flat-rate roll first (2% hazard, 3% special, checked before the tier roll so they're not tier-gated), then a distance-bucketed tier roll via `lib/rng.lua`'s `weighted()` (3 buckets by Euclidean cell distance from spawn, cumulative weights shifting from mostly-tier-1 to mostly-tier-3), then a uniform pick among that tier's 4 block ids. Bucket thresholds (`neard`/`midd`) are computed once per world in `gen_world()` from `maxd`, the spawn-to-farthest-corner distance, not fixed constants — an initial fixed 12/28-cell version, found alongside the empty-field bug, put ~80% of the 128×64 map in the tier-3-favoured "far" bucket regardless of where spawn landed (actual spawn-to-corner distances range roughly 0-140 depending on spawn position), making tier 3 the *most* common block instead of the rarest. Now scaled per-run to `maxd*0.25`/`maxd*0.55`; two post-fix runs both landed tier1 ≈ tier2 > tier3. All rates are still first-pass, not yet playtested for feel (see README's Open Questions on tuning).
- **Movement & collision**: `try_move(dx,dy)` moves each axis independently and checks only the player's centre point (`px+4,py+4`) against `mget`, not a full AABB — enough for solid-terrain movement against an 8×8-aligned grid, sliding along a wall on one axis if the other is blocked. `lib/collision.lua`'s `rect_hit` isn't used yet; that's for Phase 2+'s monster/hazard overlap. Facing (`fx`/`fy`) persists as the last non-zero movement direction, per README's Player section.
- **Camera**: `camx`/`camy`, `mid(0, player_centre-64, world_size*8-128)` per axis, set in both `_init()` (so `_draw()` never reads a nil value on the first frame) and `_update()`. Generalizes games 2/5's one-axis clamp to two, per Phase 0's note.
- **Rendering**: flat `rectfill` per visible cell, colour looked up from `bcol` (indexed by block id, values taken directly from DESIGN.md's Palette table) — no sprites yet, that's Phase 7. Only the cells inside the current camera viewport are looped (~17×17 max), not the whole 128×64 map. Player is a plain white 8×8 `rectfill`. No HUD, no fog/visibility radius, no title/state machine (`gs`) yet — `_update()`/`_draw()` run gameplay directly, matching how earlier games in this jam didn't add their title/state machine until a later phase either.
- **Verification so far**: `luac -p` syntax-checked (with `+=` temporarily desugared for the check, Pico-8-only syntax standard Lua can't parse), ran crash-free in real Pico-8 across multiple launches, and — after the empty-field bug — wall density and tier distribution are now confirmed sane via a temporary in-cart `printh()` diagnostic (added, checked, removed) rather than just a crash check. Not yet confirmed: whether the cave visually reads as organic and reasonably connected (versus disconnected pockets or unusually blocky shapes), movement/camera feel. See PLAN.md Phase 1's Verify note.

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) before writing new utility code from scratch. `lib/` covers everything this game's checklist called for: `title.lua`, `screen.lua`, `math.lua`, `state.lua` (`goto_state`/`return_state`), `collision.lua` (`rect_hit`), `map.lua` (`cell_xy`/`neighbour`), `rng.lua` (`weighted`/`shuf`), `input.lua` (`any_btnp`), `hud.lua` (`rprint`). `6.p8` so far only pastes in `map.lua`'s two functions and `rng.lua`'s `weighted` (per `lib/CLAUDE.md`'s "inline only what you need" rule — `shuf`, `collision.lua`, `state.lua`, `input.lua`, and `hud.lua` aren't needed until later phases). The camera generalization (one axis in games 2/5 to two here) is done, in Phase 1; `state.lua`'s return-tracking for a multi-caller Help overlay is still Phase 6's job. World generation, mining, combat, inventory/crafting, and chest logic are all novel to this game and aren't in `lib/`.
