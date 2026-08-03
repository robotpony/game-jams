# Plan

Phased implementation checklist for `6.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md). A few design decisions are still open (see README's Open Questions); resolve the noise-generation approach in particular before starting Phase 1, since it shapes everything downstream. Given this game's size, expect the token budget (Phase 9) to force simplification somewhere, don't treat DESIGN.md's first-pass tuning numbers or even the full 16/8/6 content counts as guaranteed to survive unchanged.

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
- [x] Distance-from-spawn biasing so tier-2/3 blocks don't cluster near spawn (`pick_block()`, distance-bucketed `weighted()` roll, bucket thresholds scaled to each run's actual spawn-to-corner distance). Chest placement itself is still Phase 6's job, per that phase's own checklist; this item only covers block-tier biasing
- [x] Player position, 8-directional movement (4 cardinal + 4 diagonal), single fixed speed (walk/run distinction dropped, see the Button mapping decision — no button left for a run modifier)
- [x] Scrolling camera, follows player, clamped at world edges (two-axis `mid()` clamp, generalizing games 2/5's one-axis version per Phase 0's note)
- [x] **KNOWN BUGS FOUND AND FIXED, post-first-playtest** — first playtest showed an empty field (almost no wall blocks rendered). Two real bugs, not a rendering issue: (1) the cellular-automata smoothing was updating cells in place instead of double-buffered, which cascades wall density from ~44% seed fill down to ~3% within 4 iterations, an almost-entirely-floor map; (2) even fixed, the 2-branch smoothing rule (`wc>=5` wall else floor) doesn't stabilize, it keeps eroding every iteration — switched to the classic tie-preserving 3-way rule (`wc>4` wall, `wc<4` floor, else keep current), which settles around a healthy ~30-40% wall density. Diagnosed by reproducing the exact algorithm outside Pico-8 (plain `lua`) before touching the cart, confirmed the fix inside real Pico-8 via a temporary `printh()` diagnostic (added, checked, then removed), not by eyeballing. Also caught while diagnosing: the near/mid distance-bucket thresholds (originally fixed at 12/28 cells) were far too small for a 128×64 map — spawn-to-corner distances range roughly 0-140 depending on where spawn lands, so a fixed 28-cell "far" cutoff put ~80% of the map in the tier-3-favoured bucket, making tier 3 the *most* common block instead of the rarest. Now scaled to each run's actual spawn-to-corner distance (`neard`/`midd` computed from `maxd`, the farthest map corner from spawn). Two runs post-fix: wall 33-39% of map, tier1 ≈ tier2 > tier3 both times.
- [x] Verify (partial): syntax-checked (`luac -p`), and confirmed via `printh()` diagnostics inside real Pico-8 (not just crash-checked) that wall density and tier distribution are now sane across multiple seeds. What's *still* not confirmed: whether the cave visually reads as organic/connected (versus, say, disconnected pockets or unusually blocky shapes), and general movement/camera feel — those genuinely need eyes on it. `pico8 -run 6.p8` to look for yourself.

## Phase 2: Mining

- [x] Block resistance/HP model: mining input, tool-tier gate, damage-over-time breaking
- [x] Tool tiers 1-3 (Basic/Mid/Advanced Pick), each with its own power value
- [x] Block drops added to inventory on break — "inventory" here is a flat `mat[]` count-by-block-id table, not the 8-slot equip inventory (that's Phase 5's job; README's 8 general item types are tools/weapons/Lantern/Health-Potion, not raw materials, so `mat[]` is likely the material store's final shape, not a Phase 5 placeholder)
- [x] Hazard blocks: Lava (contact damage), Deep Water (movement penalty), neither mined
- [x] Treasure Vein and Glowstone: always-breakable regardless of equipped tool tier
- [x] **Found and fixed a Phase 1 bug while wiring this up**: `try_move`'s collision check only allowed movement onto `mget==0` (floor), which made lava/deep-water cells solid, same as a wall block — that's wrong per README ("damages on contact" / "slows movement" both imply the tile is walkable). Added `walkable(t)` (`t==0 or t==13 or t==14`) and switched the collision check to it; deep water's movement penalty is applied as a per-axis speed multiplier (`spd*0.5`) rather than a block.
- [x] Design call: Treasure Vein/Glowstone (ids 15/16) reuse tier-1's exact resistance(1)/hp(10) rather than a separate tier-0 path — "always-breakable regardless of tool tier" falls out for free once the equipped tool is never below tier 1. README's "guaranteed bonus drop" language for Treasure Vein isn't implemented yet (it currently just drops one `mat[15]` like any other block); flagged as a follow-up once Phase 5's crafting/Phase 6's coins exist to give a bonus something to pay out in, not implemented a phase early for one edge case.
- [x] Verify: confirmed via a temporary in-cart `printh()` self-test (`_init()`-time, added/checked/removed, same pattern as Phase 1's diagnostic) in real Pico-8, not just eyeballing: a tier-2 block resists a tier-1 tool (id/hp unchanged) but breaks under a tier-2 tool with a drop recorded in `mat[]`; Glowstone breaks under a tier-1 tool; standing in lava for 46 frames ticked hp from 10 to 7 (3 ticks at the 15-frame rate); a deep-water cell reports `walkable()==true`. Cart still runs crash-free end to end after removing the diagnostic. Not yet confirmed: mining/hazard *feel* (tick rate, damage numbers) with a human at the controls — those are first-pass per DESIGN.md and still need real playtesting once there's more to play against.

## Phase 3: Map edge wraparound

- [x] Replace `try_move`'s edge clamp with a wrap: movement that would cross a map boundary teleports the player to the corresponding position on the opposite edge instead of stopping in place
- [x] Guard against wrapping onto solid wall/hazard: if the mirrored cell on the opposite edge isn't floor, nudge along that edge to the nearest floor cell rather than embedding the player in rock — `wrap_axis(axis,newmajor,minor,lim)` does this generically for both x-wrap and y-wrap (one function, not two), searching outward (`mcell+r*s` alternating ±) from the direct-mirror row/column
- [x] Camera: no new code needed, confirmed — `_update()`'s existing per-frame `mid()` clamp already recomputes from live `px`/`py`, so a wrap reads as a hard camera cut, not a smooth pan
- [x] Known accepted edge case, documented in `try_move`'s header comment rather than fixed: diagonal movement into a corner that needs `wrap_axis`'s floor-search on the x-axis can carry that adjusted `py` into the y-axis check that runs right after (both axes still process sequentially against live `px`/`py`, same as the pre-existing dx-then-dy pattern). Only ever nudges the landing spot to nearby floor, doesn't break the wrap; not worth a bigger rewrite for a diagonal-into-a-corner-that-also-needs-sliding case.
- [x] Verify: confirmed via a temporary in-cart `printh()` self-test (`_init()`-time, added/checked/removed, same pattern as Phase 1/2's diagnostics) in real Pico-8: left-edge wrap with a direct floor mirror lands exactly on the opposite edge at the same row; same for right-edge and top-edge wraps; a left-edge wrap where the direct mirror cell is forced to wall correctly slides one row down to the nearest floor cell instead. Cart still runs crash-free after removing the diagnostic. Not yet confirmed: actual play feel of wrapping while exploring a real generated cave (all four test cases above force specific map cells rather than exercising a natural spawn-to-edge walk), and the bottom-edge/right-edge-mirror-is-wall slide paths specifically (only left/wall and left/right/top-direct were exercised — by symmetry the other three wrap directions share the same code path, so this is a reasonable confidence gap, not a known-untested risk).

## Phase 4: Combat & monsters

- [x] Weapon swing (attack) and parry (timed defend), tiers 1-3 (Basic/Mid/Advanced Blade). `wtier` is a placeholder equip-tier global (1 for now), same pattern as Phase 2's `tool` — Phase 5's real equip slot sets both for real.
- [x] Player HP, damage taken, death at 0 — `dead` freezes `_update()` entirely (a hard early-return) rather than a real game-over flow, since the End screen/state machine don't exist until Phase 7. `hp` existed a phase early already (Phase 2's lava damage); Phase 4 gives it its real purpose.
- [x] 6 monster types: Cave Bat, Rock Crawler, Spitting Slug, Tunnel Wraith, Bone Archer, Cave Warden, each with distinct HP/damage and a melee or ranged attack pattern — one shared `upd_mon()` driven by per-type `mhp`/`mdmg`/`mspd`/`mrng` tables rather than six special-cased functions, in the same flat-array-by-id style the rest of the cart already uses. **Scope cut**: Cave Warden's "melee + occasional ranged, mini-boss" is approximated as Spitting Slug's short-ranged tier (same code path) rather than real dual-mode AI — the highest-HP/distinct-colour/distance-gated parts of "mini-boss" are there, the mixed attack-mode flavour isn't. Cave Bat's "erratic" movement is a cheap per-frame random jitter layered on a normal chase, not a real flight pattern.
- [x] Monster-specific drops on death — extends Phase 2's `mat[]` (block ids 1-16) with monster-drop ids 17-22 (`16+typ`) rather than a second table.
- [x] Monster spawn/difficulty scaling with distance from spawn — `gen_monsters()` reuses `pick_block()`'s exact distance-bucket mechanism (near/mid/far `weighted()` rolls against `neard`/`midd`, already computed once per world in `gen_world()`) rather than a second distance-bias system; 12 monsters placed on random floor cells at `_init()` time.
- [x] **Found and fixed a real bug while wiring up hit-detection and AI movement**: Pico-8 numbers are 16.16 fixed-point (~32767 ceiling on the integer part), and this map is 1024×512px — squaring a raw pixel-space distance (`dx*dx`) for anything past ~181px silently overflows/wraps instead of erroring, corrupting both `try_attack`'s melee hit-check and `upd_mon`'s chase-direction math for any monster more than ~181px from the player, which is most of them on a map this size. Diagnosed with a temporary in-cart `printh()` dump of the actual computed values (not guessed at): a mid-distance monster's squared distance printed as a negative number, which happened to satisfy `<64` and made the attack silently hit (and jump-cooldown) the wrong, undamaged-looking monster while leaving the real target alive — the kind of bug that reads as "sometimes just doesn't work" without a debug dump. Fixed by doing all AI/hit distance math in cell units (divide by 8) instead of pixels, since direction (`dx/d`, `dy/d`) is scale-invariant so pixel-space movement is unaffected; `try_attack` additionally pre-filters with a cheap `abs(ddx)<8 and abs(ddy)<8` check before ever squaring, both cheaper and overflow-safe. `mrng`'s engage-range values are now in cells, not pixels, documented at the table.
- [x] Verify: confirmed via a temporary in-cart `printh()` self-test (`_init()`-time, added/checked/removed, same pattern as Phases 1-3), in real Pico-8, only after finding and fixing the overflow bug above (the original version of this same test is what surfaced it): a weapon swing kills a 1-hp monster and records its drop in `mat[17]`; damage taken during an active parry window doesn't reduce hp and clears the window, the same damage with no parry active does reduce hp by the expected amount; forcing hp to 0 sets `dead`; 300 rolls each against the near-bucket and far-bucket cum tables skew tier-1-heaviest and tier-3-heaviest respectively, matching `pick_block`'s existing bias direction; a melee type closes distance toward the player, a ranged type (bone archer) closes when far and retreats when crowded. Cart still runs crash-free after removing the diagnostic. Not yet confirmed: real playtest feel — whether each monster's attack pattern actually *reads* as distinct to a human at the controls (melee-vs-ranged and speed/range differences exist in the code, but "reads as distinct" is a feel question the unit-style self-test can't answer), parry window timing (still the design's untested 8-frame guess), and monster density/difficulty-curve tuning (all first-pass per DESIGN.md).

## Phase 5: Inventory, equipment & crafting

- [ ] 8 general item-type slots (3 tools, 3 weapons, Lantern, Health Potion), each stacking up to 99 per slot
- [ ] 2 dedicated equip slots (tool, weapon), separate from the 8 general slots; only the equipped tool/weapon affects mining/combat
- [ ] Coins counter, separate from the 8 item types, capped at 255
- [ ] Crafting: flat recipe lookup table, checked against current materials, craftable recipes highlighted
- [ ] Runic Pick / Runic Blade (tool/weapon tier 4): craftable from Ancient Stone, don't occupy a general slot (like the Book), auto-equip into the tool/weapon slot the instant they're crafted
- [ ] Health Potion consumption (restores HP)
- [ ] Verify: equipping a different tool/weapon actually changes what can be mined/how much damage is dealt; every recipe in README's table produces the right item for the right cost; crafting Runic Pick/Blade lands directly in the equip slot, not a general inventory slot

## Phase 6: Chests & help

- [ ] Chest placement during world generation, modest spawn rate
- [ ] Chest interaction: walk up, interact input, instant loot reveal (no timed search)
- [ ] Loot table: weighted materials/potion/book, book capped at one
- [ ] Book: special non-slot persistent item, found once, re-usable
- [ ] Help overlay: controls, tool-tier/block-tier reference, monster-drop/recipe reference
- [ ] Verify: a found chest's loot matches the weighted table over many rolls (harness-checkable); the Help overlay is reachable from Inventory once the book is found, and shows accurate reference data

## Phase 7: Screens & flow

- [ ] Title screen: shared jam title card
- [ ] Game screen: cave view + HUD wired together
- [ ] End screen: death stats (coins, distance reached, score)
- [ ] State machine: title → playing → (inventory ↔ playing) → (help, from inventory or playing, once book found) → end → title
- [ ] Verify: full loop is playable start to finish; inventory and help overlays open/close without breaking state

## Phase 8: Visuals & sound polish

- [ ] Apply final colour palette once the visual-style conversation resolves it (see DESIGN.md's Palette table)
- [ ] Player, monster (6 types), block (16 types), chest, and item sprites
- [ ] SFX for the event list README's Sound section needs, once decided
- [ ] Verify: play a full round with sound on, confirm every SFX fires at its correct trigger

## Phase 9: Token & performance check

- [ ] Confirm final token count is within the ~8,192 budget — high risk given this game's scope (see DESIGN.md's Token budget note); expect to cut or simplify something (fewer block/monster types, simpler noise approximation, fewer recipes) rather than assume it fits
- [ ] Confirm the world renders and mining/combat/monster-AI logic run without frame drops with multiple monsters and a chest on screen at once
