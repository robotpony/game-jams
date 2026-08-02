# Plan

Phased implementation checklist for `6.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md). A few design decisions are still open (see README's Open Questions); resolve the noise-generation approach in particular before starting Phase 1, since it shapes everything downstream. Given this game's size, expect the token budget (Phase 8) to force simplification somewhere, don't treat DESIGN.md's first-pass tuning numbers or even the full 16/8/6 content counts as guaranteed to survive unchanged.

## Phase 0: Shared lib/ prerequisites

CLAUDE.md and this plan both assumed `lib/` already covers input, state machine, tweening, collision, HUD, map queries, and seeded RNG. It doesn't: only `screen.lua`, `title.lua`, and `math.lua` exist (see [`../lib/CLAUDE.md`](../lib/CLAUDE.md) and [`../lib/PLAN.md`](../lib/PLAN.md)). Game 6 needs exactly the missing ones, and this is the most token-tight game in the jam, so build these first rather than discovering the cost mid-Phase-1.

- [ ] `lib/state.lua`: finite state machine (init/update/draw dispatch) covering the 5 scenes (`gs` 0-4) plus a return-state variable for the Help overlay (openable from Playing or Inventory, must resume whichever it was opened from — game 2's `help_on` precedent doesn't need this since it only ever has one caller state)
- [ ] `lib/collision.lua`: AABB helpers for pixel and tile collision (player-block for mining/movement, player-monster, player-hazard)
- [ ] `lib/map.lua`: map query helpers (tile flags, neighbour checks) for block resistance/HP lookups
- [ ] `lib/rng.lua`: seeded RNG wrapper, weighted-choice (loot tables, distance-biased block/monster selection), Fisher-Yates shuffle (already scoped in `lib/PLAN.md`'s Confirmed/Gaps sections, not yet built)
- [ ] `lib/input.lua`: `any_btnp()` for "any button" scene transitions (already scoped in `lib/PLAN.md`'s Gaps section, not yet built)
- [ ] `lib/hud.lua`: right-aligned number printing (already scoped in `lib/PLAN.md`'s Confirmed section); confirm it covers this game's icon-based HP/coins/equipment HUD or note where it falls short
- [ ] Also generalize the camera clamp: games 2 and 5's clamped camera each clamp one axis only (vertical shaft/stack); game 6's top-down cave needs both x and y clamped against world bounds. Not a straight copy-paste.
- [ ] Update `lib/PLAN.md`'s checkboxes and folder-layout note as each file lands
- [ ] Verify: each new lib/ file runs standalone (minimal test cart or harness) before Phase 1 starts building on top of it

## Phase 1: World generation & camera

- [ ] Resolve the noise-generation approach (see Open Questions) and implement cave generation into Pico-8's native map
- [ ] Distance-from-spawn biasing so tier-2/3 blocks and chests don't cluster near spawn
- [ ] Player position, 8-directional movement (4 cardinal + 4 diagonal), walk/run speeds
- [ ] Scrolling camera, follows player, clamped at world edges (reuse game 2/5's clamping pattern)
- [ ] Verify: cave generates without errors across multiple seeds, easy material is near spawn and harder material further out, camera never shows past the world edge

## Phase 2: Mining

- [ ] Block resistance/HP model: mining input, tool-tier gate, damage-over-time breaking
- [ ] Tool tiers 1-3 (Basic/Mid/Advanced Pick), each with its own power value
- [ ] Block drops added to inventory on break
- [ ] Hazard blocks: Lava (contact damage), Deep Water (movement penalty), neither mined
- [ ] Treasure Vein and Glowstone: always-breakable regardless of equipped tool tier
- [ ] Verify: a low tool tier genuinely can't progress on a block above its resistance; breaking a block yields its drop

## Phase 3: Combat & monsters

- [ ] Weapon swing (attack) and parry (timed defend), tiers 1-3 (Basic/Mid/Advanced Blade)
- [ ] Player HP, damage taken, death at 0
- [ ] 6 monster types: Cave Bat, Rock Crawler, Spitting Slug, Tunnel Wraith, Bone Archer, Cave Warden, each with distinct HP/damage and a melee or ranged attack pattern
- [ ] Monster-specific drops on death
- [ ] Monster spawn/difficulty scaling with distance from spawn
- [ ] Verify: parry timing actually negates damage within its window; each monster's attack pattern reads as distinct; harder monsters appear further from spawn

## Phase 4: Inventory, equipment & crafting

- [ ] 8 general item-type slots (3 tools, 3 weapons, Lantern, Health Potion), per-slot stack limit (TBD, see Open Questions)
- [ ] 2 dedicated equip slots (tool, weapon), separate from the 8 general slots; only the equipped tool/weapon affects mining/combat
- [ ] Coins counter, separate from the 8 item types, capped at 255
- [ ] Crafting: flat recipe lookup table, checked against current materials, craftable recipes highlighted
- [ ] Health Potion consumption (restores HP)
- [ ] Verify: equipping a different tool/weapon actually changes what can be mined/how much damage is dealt; every recipe in README's table produces the right item for the right cost

## Phase 5: Chests & help

- [ ] Chest placement during world generation, modest spawn rate
- [ ] Chest interaction: walk up, interact input, instant loot reveal (no timed search)
- [ ] Loot table: weighted materials/potion/book, book capped at one
- [ ] Book: special non-slot persistent item, found once, re-usable
- [ ] Help overlay: controls, tool-tier/block-tier reference, monster-drop/recipe reference
- [ ] Verify: a found chest's loot matches the weighted table over many rolls (harness-checkable); the Help overlay is reachable from Inventory once the book is found, and shows accurate reference data

## Phase 6: Screens & flow

- [ ] Title screen: shared jam title card
- [ ] Game screen: cave view + HUD wired together
- [ ] End screen: death stats (coins, distance reached, score)
- [ ] State machine: title → playing → (inventory ↔ playing) → (help, from inventory or playing, once book found) → end → title
- [ ] Verify: full loop is playable start to finish; inventory and help overlays open/close without breaking state

## Phase 7: Visuals & sound polish

- [ ] Apply final colour palette once the visual-style conversation resolves it (see DESIGN.md's Palette table)
- [ ] Player, monster (6 types), block (16 types), chest, and item sprites
- [ ] SFX for the event list README's Sound section needs, once decided
- [ ] Verify: play a full round with sound on, confirm every SFX fires at its correct trigger

## Phase 8: Token & performance check

- [ ] Confirm final token count is within the ~8,192 budget — high risk given this game's scope (see DESIGN.md's Token budget note); expect to cut or simplify something (fewer block/monster types, simpler noise approximation, fewer recipes) rather than assume it fits
- [ ] Confirm the world renders and mining/combat/monster-AI logic run without frame drops with multiple monsters and a chest on screen at once
