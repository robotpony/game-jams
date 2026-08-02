# Plan

Phased implementation checklist for `6.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md). A few design decisions are still open (see README's Open Questions); resolve the noise-generation approach in particular before starting Phase 1, since it shapes everything downstream. Given this game's size, expect the token budget (Phase 8) to force simplification somewhere, don't treat DESIGN.md's first-pass tuning numbers or even the full 16/8/6 content counts as guaranteed to survive unchanged.

## Phase 0: Shared lib/ prerequisites

CLAUDE.md and this plan both assumed `lib/` already covers input, state machine, tweening, collision, HUD, map queries, and seeded RNG. It doesn't: only `screen.lua`, `title.lua`, and `math.lua` exist (see [`../lib/CLAUDE.md`](../lib/CLAUDE.md) and [`../lib/PLAN.md`](../lib/PLAN.md)). Game 6 needs exactly the missing ones, and this is the most token-tight game in the jam, so build these first rather than discovering the cost mid-Phase-1.

- [x] `lib/state.lua`: `goto_state(ns)`/`return_state()` (`gs`/`gsret` pair), covering the "resume whichever state opened this overlay" need for the Help screen (openable from Playing or Inventory — game 2's `help_on` precedent doesn't need this since it only ever has one caller state). Deliberately not a full dispatch-table FSM; games 1/2/3/5's plain `if gs==n then` chains stay the pattern for the 5-scene main dispatch, since a generic table-of-functions dispatcher costs more tokens per call than that for this few states. See the file's own header comment.
- [x] `lib/collision.lua`: `rect_hit(x1,y1,w1,h1,x2,y2,w2,h2)` AABB overlap check, for player-block, player-monster, player-hazard checks.
- [x] `lib/map.lua`: `cell_xy(px,py)` pixel-to-cell conversion, `neighbour(cx,cy,i)` 8-directional (Moore neighbourhood) cell offset — bumped from 4 to 8 during Phase 1 once cave smoothing needed a real Moore wall-count. `mget`/`mset` themselves aren't wrapped, calling them directly costs the same as a wrapper with no savings.
- [x] `lib/rng.lua`: `weighted(vals,cum,total)` cumulative-threshold roll (loot tables, distance-biased block/monster selection) and `shuf(t)` Fisher-Yates shuffle, both now built (moved out of `lib/PLAN.md`'s backlog into Built).
- [x] `lib/input.lua`: `any_btnp()` for "any button" scene transitions, now built (moved out of `lib/PLAN.md`'s Gaps into Built).
- [x] `lib/hud.lua`: `rprint(s,rightx,y,col)` right-aligned print, now built. Covers this game's icon-based HP/coins/equipment HUD for any numeric/text labels next to the icons; the icons themselves are sprite draws, not something this function needs to touch.
- [x] Camera clamp: decided **not** to add a dedicated lib function. Games 2/5's one-axis `mid(0,cy-44,maxcamy)` pattern generalizes to two axes as two `mid()` calls (`mid(0,px-64,maxx)`, `mid(0,py-64,maxy)`); `mid()` is already a single cheap builtin call, so a wrapper would cost tokens without saving any (same reasoning `lib/PLAN.md`'s Open question already applies to `math.lua`'s clamped increment/decrement). Just remember it's two calls, not a copy-paste of the one-axis version, when Phase 1 writes the actual camera code.
- [x] Updated `lib/PLAN.md`'s checkboxes and `lib/CLAUDE.md`'s folder-layout note to reflect all six new files.
- [x] Verify: all six new files parse cleanly (`luac -p`, standard Lua; none use pico-8-only operator syntax so this is a valid proxy). That confirms syntax only, not in-cart behaviour, since `6.p8` doesn't exist yet to paste them into — real behavioural verification happens as each function gets used for real starting in Phase 1.

## Phase 1: World generation & camera

- [x] Resolve the noise-generation approach (see Open Questions) and implement cave generation into Pico-8's native map — cellular automata floor/wall carve, no continuous noise function; see DESIGN.md's World generation
- [x] Distance-from-spawn biasing so tier-2/3 blocks don't cluster near spawn (`pick_block()`, distance-bucketed `weighted()` roll, bucket thresholds scaled to each run's actual spawn-to-corner distance). Chest placement itself is still Phase 5's job, per that phase's own checklist; this item only covers block-tier biasing
- [x] Player position, 8-directional movement (4 cardinal + 4 diagonal), single fixed speed (walk/run distinction dropped, see the Button mapping decision — no button left for a run modifier)
- [x] Scrolling camera, follows player, clamped at world edges (two-axis `mid()` clamp, generalizing games 2/5's one-axis version per Phase 0's note)
- [x] **KNOWN BUGS FOUND AND FIXED, post-first-playtest** — first playtest showed an empty field (almost no wall blocks rendered). Two real bugs, not a rendering issue: (1) the cellular-automata smoothing was updating cells in place instead of double-buffered, which cascades wall density from ~44% seed fill down to ~3% within 4 iterations, an almost-entirely-floor map; (2) even fixed, the 2-branch smoothing rule (`wc>=5` wall else floor) doesn't stabilize, it keeps eroding every iteration — switched to the classic tie-preserving 3-way rule (`wc>4` wall, `wc<4` floor, else keep current), which settles around a healthy ~30-40% wall density. Diagnosed by reproducing the exact algorithm outside Pico-8 (plain `lua`) before touching the cart, confirmed the fix inside real Pico-8 via a temporary `printh()` diagnostic (added, checked, then removed), not by eyeballing. Also caught while diagnosing: the near/mid distance-bucket thresholds (originally fixed at 12/28 cells) were far too small for a 128×64 map — spawn-to-corner distances range roughly 0-140 depending on where spawn lands, so a fixed 28-cell "far" cutoff put ~80% of the map in the tier-3-favoured bucket, making tier 3 the *most* common block instead of the rarest. Now scaled to each run's actual spawn-to-corner distance (`neard`/`midd` computed from `maxd`, the farthest map corner from spawn). Two runs post-fix: wall 33-39% of map, tier1 ≈ tier2 > tier3 both times.
- [x] Verify (partial): syntax-checked (`luac -p`), and confirmed via `printh()` diagnostics inside real Pico-8 (not just crash-checked) that wall density and tier distribution are now sane across multiple seeds. What's *still* not confirmed: whether the cave visually reads as organic/connected (versus, say, disconnected pockets or unusually blocky shapes), and general movement/camera feel — those genuinely need eyes on it. `pico8 -run 6.p8` to look for yourself.

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

- [ ] 8 general item-type slots (3 tools, 3 weapons, Lantern, Health Potion), each stacking up to 99 per slot
- [ ] 2 dedicated equip slots (tool, weapon), separate from the 8 general slots; only the equipped tool/weapon affects mining/combat
- [ ] Coins counter, separate from the 8 item types, capped at 255
- [ ] Crafting: flat recipe lookup table, checked against current materials, craftable recipes highlighted
- [ ] Runic Pick / Runic Blade (tool/weapon tier 4): craftable from Ancient Stone, don't occupy a general slot (like the Book), auto-equip into the tool/weapon slot the instant they're crafted
- [ ] Health Potion consumption (restores HP)
- [ ] Verify: equipping a different tool/weapon actually changes what can be mined/how much damage is dealt; every recipe in README's table produces the right item for the right cost; crafting Runic Pick/Blade lands directly in the equip slot, not a general inventory slot

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
