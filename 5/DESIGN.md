# 5 To The Top — Design

`5.p8` now exists and implements all 7 PLAN.md phases, but this document remains the source of truth rather than being superseded: CLAUDE.md's status note explains the Architecture-section handoff is deliberately held open until Phase 3's known-broken rope grab and Phase 7's frame-rate check are resolved. See [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md) for what this document covers versus [README.md](README.md) and [CLAUDE.md](CLAUDE.md).

## World layout & camera

**Minimum row spacing**: the climb gap between two rows must be at least 2x the player sprite's height (8px), 3x if it can be afforded, so the player is never cramped mid-jump or mid-climb. At 3x (24px gap + 8px platform = 32px pitch), a single 128px screen only fits about 4 rows — not enough room for a level that reads as a real climb (an earlier draft tried to fit 6 rows into one screen by shrinking the gap to 8px, well under the 2x floor, and it read as cramped). Fitting more rows without violating the gap minimum means the level has to be taller than one screen, so the game needs a scrolling camera.

**World size**: the level is 3 screens tall (336px of scrollable world, where a "screen" here means the 112px playfield viewport — 128px minus the HUD's fixed 16px, which never scrolls). Solving `336 = 16 (spawn band + ground row) + rows * 32 (pitch)` gives exactly **10 rows**: Platform 1 (lowest) through Platform 9, then the Finish platform — up from the single-screen draft's 3 platforms, then 5 platforms, in two earlier iterations.

World-space y-coordinates (top of world = 0, near the finish; bottom = 335, at the ground):

```
y=0-7      hazard spawn band: items enter here at a random column
y=8-15     row 9 (finish): 8px platform row, holds the level-advance button
y=16-39    climb gap (24px): row9↔row8
y=40-47    row 8 (platform 9): 8px platform row
...        (repeats: 8px row, 24px gap, at 32px pitch)
y=296-303  row 0 (platform 1): 8px platform row
y=304-327  climb gap (24px): row0↔ground
y=328-335  ground row: player start, not randomized (always solid, no hazards below it)
```

- Ten platform rows (`rowy(idx) = 296 - 32*idx` for `idx=0..9`; ground is `idx=-1` at `y=328`), each 8px tall, 16 columns of 8px tiles spanning x=0–127.
- 24px climb gaps between consecutive rows (and between row 0 and ground) hold that row pair's ladder — comfortably above the 2x-sprite-height floor.
- Ground row is fixed, always solid, never randomized; the player starts here every level, at world `y=320`.
- **Camera**: `camera_y = mid(0, py - 56, 224)` every frame — keeps the player roughly vertically centred in the 112px viewport, clamped so the camera never scrolls past the world's top (finish fully visible) or bottom (ground fully visible, matching the original single-screen framing at level start). All world-space draw calls (rows, ladders, boxes, rope, hazards, player) subtract `camera_y`; the HUD is drawn last against the raw screen coordinates so it stays fixed regardless of scroll.
- HUD: screen `y=112–127`, left-aligned lives (numeric), centred level number, right-aligned score — matches the project's left/center/right HUD convention (see [`../3/DESIGN.md`](../3/DESIGN.md)).
- **Known consequence, not yet addressed**: hazards still spawn at the world's absolute top (`y=0`, by the finish) regardless of where the camera currently is, same as the single-screen draft. In a 336px-tall world that means early climbing near the ground can go a while (roughly 280 frames at the level-1 fall speed) before the first hazard's fall reaches the visible viewport — the tower's danger builds as you climb rather than being present from frame one. That may read as a nice difficulty curve or as an empty start; if playtesting says the latter, switch to spawning just above the current camera position instead of the world's absolute top.

## Palette

| Element | Colour | Index |
| ------- | ------ | ----- |
| Background | Black | 0 |
| Platform / beam | Brown | 4 |
| Ladder rungs | Orange | 9 |
| Box outline | White | 7 |
| Rope | Yellow | 10 |
| Finish button (flash) | Gold / white | 10 / 7 |
| Player shirt | Red | 8 |
| Player jeans | Blue | 12 |
| Player skin | Tan | 15 |
| Tumbleweed / barrel fill | Brown | 4 |
| Barrel rings | Black | 0 |
| Hazard bottle | Amber | 9 |
| Wagon wheel | Grey / brown hub | 6 / 4 |
| Gun | Silver / grip | 6 / 4 |
| Prize bottle, green | Green | 11 |
| Prize bottle, red | Red | 8 |
| HUD text | White | 7 |

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | Startup | 1 (any button) |
| 1 | Playing | Title, or Level transition complete | 2 (finish button reached); 3 (lives reach 0) |
| 2 | Level transition | Playing (finish button reached) | 1 (flicker complete, next level loaded) |
| 3 | End | Playing (lives reach 0) | 0 (any button) |

## Core system design

### Level generation

Each row (0–9, bottom to top of the ten platform rows) is a 16-element array of tile types, generated independently per level:

1. For each row, for each column, roll `gap` vs `platform` weighted by the level's gap density (see Progression below; starts around 15%, rises with level, capped around 35%).
2. For each pair of adjacent rows (ground↔row0, row0↔row1, ... , row8↔row9), pick one column that is `platform` in both rows and mark it as a **ladder connector**. If no shared-platform column exists between a pair after step 1's roll, force one column in each of the two rows to `platform` and use it as the connector, so every level is completable by construction. Ladder is the only connector type — every level therefore has a guaranteed ladder at all 10 row-pairs.
3. For each row, roll a **box** obstacle onto some of its platform tiles (see Box obstacles below), excluding whichever column(s) that row uses as a ladder connector (as either the lower or upper end of a pair) so a box can never block a ladder, and excluding any column with a gap tile on either horizontal side so a box can never trap a gap between itself and another box, making that gap unreachable on foot (see Box obstacles' note on this).
4. Pick one row-pair and column to hold the level's single **rope anchor**, excluding that pair's ladder connector column and any column with a box on either the pair's lower or upper row. A first play test skipped the box exclusion, and the rope sometimes landed on the same column as a box — visually overlapping it and blocking the player from reaching the correct standing position to grab it, since a box on the lower row blocks horizontal approach at ground height (see Player movement & collision). If the stronger exclusion leaves no candidate column at all (not observed in a 3,000-trial check, but not structurally impossible), fall back to excluding only the ladder connector's column.

Every level has a full ladder path from ground to finish by construction (step 2's force-a-connector fallback guarantees it). It does not by itself guarantee the player can *walk* from one row's landing point to that row's connector column without a jump-worthy run of gap tiles in between — with gap density capped at 35% (see Progression), a long unbroken run of gaps between connectors is possible though statistically rare. A 2,000-trial simulation of the generation algorithm (connector and box placement, no jump-range check) found zero cases of a missing connector, a box on a ladder's column, or a box on a gap tile, but it can't rule out an occasional hard-to-cross row; this is exactly what Phase 1's manual "generate several levels and confirm a path exists" verify step in [PLAN.md](PLAN.md) is for. If playtesting finds it's a real problem, harden step 1 or 2 with a same-row reachability check (e.g. no run of gap tiles longer than the player's jump range) rather than just widening jump distance.

### Box obstacles

A box is a static obstacle sitting on top of a platform tile, occupying the same 8px band the player's body does while standing on that row — the player has to jump over it, not through it, the same way a gap has to be jumped over rather than walked through. Roll chance is per platform tile, independent of the ladder-connector exclusion in Level generation step 3 (roughly 15% at level 1; not currently part of the difficulty ramp, see Progression).

An earlier draft had "stairs/box" as an alternate *vertical* connector, floating mid-gap between two rows; it moved onto the platform surface as a horizontal obstacle by direct design correction, not because of a space constraint — the current 24px climb gap would comfortably fit a floating step again. Ladders are the sole vertical connector regardless of gap size.

A first play test of this on-platform version found the player could walk straight into a box without being stopped, popping up onto it without any jump — because horizontal movement had no collision check at all, only vertical. See Player movement & collision below for the fix.

A later play test found a second-order consequence of that fix: if a gap tile happened to have boxes on both of its neighbouring columns, the player couldn't reach the gap at all — box collision (correctly) blocked the walk-up approach from either side, and jumping over one box to land precisely on the narrow gap tile beyond it was unreasonably fiddly ("some spaces between platforms are too narrow to fall down"). Fixed in Level generation step 3: a box can no longer be placed adjacent to a gap tile on either side, so every gap always has a clear, walkable approach from at least one direction without needing to clear a box first. Verified with a 2,000-trial harness: zero cases of a box landing next to a gap (on top of the pre-existing zero cases of a box on a ladder's column or a gap tile itself).

### Player movement & collision

- **Horizontal**: each frame's desired x-move is checked against `solid_at()` at the player's current y before it's applied; if the target position would overlap a solid, `px` is clamped to sit flush against that solid's edge instead of moving into it. Platform-row tiles never trigger this (a standing player's body occupies the 8px band directly *above* that row's own tile, so there's no y-overlap to collide against), so in practice this only matters for box obstacles — the player is stopped at a box's side and has to jump to get on top of it or over it, rather than sliding through.
- **Vertical**: unchanged from earlier phases — falling/jumping resolve against whatever solid the player's new y-position would overlap, landing on top (`pvy>=0`) or bumping the underside (`pvy<0`).
- **Box height**: a box's top surface is 8px above the row's normal standing height (the box occupies the exact band a standing player's body already fills, so standing *on* it means one more full body-height up: `py = rowy(r)-16` versus the row's own `rowy(r)-8`). That's well within the ~12.9px jump apex, so a small hop is enough to mount it; a jump with more forward speed clears over the top and lands on the far side instead. Neither route reaches the row above — the extra height a box gives isn't enough to substitute for a ladder (confirmed across 100 simulated jump timings approaching the same box: none ever landed standing at the row-above's height, and 10 of the 100 did land standing exactly on the box's top at some point during the run).
- **Level edges**: there's no wall at column 0 or column 15 beyond the ordinary tile/gap roll — if the edge column happens to be a gap, the player falls through it exactly like any interior gap (verified: an edge-gap regression test falls all the way to the row below, same as a mid-row gap). `px` is still clamped to `[0,120]` so the player's sprite never leaves the 16-column grid horizontally, since there's no tile data beyond it.

### Hazard spawn and movement

- Spawn timer counts down; on reaching 0, a hazard is added at world `y=0` (the absolute top, by the finish — see World layout & camera's note on this being a known, not-yet-addressed consequence of the scrolling world), a random column, a random type (tumbleweed/barrel/hazard-bottle/wagon-wheel, equal weight, sprite-only difference), and a random roll direction (left/right).
- Each frame, a hazard falls at the current global fall speed until its `y` reaches a row's band.
- On reaching a row: if its column is `gap` in that row, it keeps falling into the next row's band (or off the bottom of the world, despawning, if it was already at row 0). If its column is `platform`, it rolls horizontally in its assigned direction at a fixed roll speed.
- While rolling, reaching a column that's a `gap` in that row makes it fall through. Reaching past column 0 or column 15 (the level's true edges) reverses its roll direction — it bounces back the way it came rather than despawning. **Box obstacles don't affect a rolling hazard at all**: it passes straight through a box's column and keeps going in the same direction, rendered *behind* the box (boxes are drawn after hazards in `draw_playing()`, so a box visually occludes any hazard currently under it) so the box reads as something the hazard is briefly obscured by, not something it collides with.
- Collision with the player (bounding-box overlap) costs 1 life and starts a short invincibility window (roughly 1s) during which further hazard contact is ignored, so a single hazard graze can't chain multiple hits.
- **Revision history on the box interaction**: an earlier version made hazards bounce off boxes the same way they bounce off the level's true edges. A play test found this could trap a hazard bouncing forever between two boxes with no gap between them ("falling items get stuck between boxes") — exactly the edge case flagged (and left unguarded) in an earlier draft of this section. Rather than add generation-time guarantees against that specific box arrangement, the interaction itself was removed: hazards now ignore boxes entirely (matching the player-suggested fix — "move behind a box unless it's at the end of a row" — which the existing edge-bounce already covers for real, since a box sitting at column 0 or 15 doesn't change what happens when a hazard tries to roll past the true edge). Verified with harnesses: a hazard between two boxes with a gap further along reaches and falls through it; a hazard between two boxes on a row with no gap at all still reaches both true edges rather than getting stuck oscillating between the boxes.

### Rope swing

The rope hangs from a fixed anchor at the top of its assigned gap and swings continuously and automatically, whether or not the player is anywhere near it — it never stops or waits. This replaced a first version where the player grabbed a rope that started perfectly still (angle 0, zero velocity) and had to pump left/right to build up motion from scratch: physically consistent, but a play test found it unusable — grabbing it and not immediately knowing to alternate-pump left/right meant literally nothing moved, which read as "the rope doesn't do anything" rather than "you need to build momentum." A continuously-swinging rope (the classic Pitfall! model) sidesteps that entirely: motion is visible before you ever touch it, so there's no discoverability problem, and the skill moves from *building* the swing to *timing* the grab and release.

- **Motion**: the bob's angle is `theta = rope_amp * sin(rope_freq * time())` — `rope_amp=0.15` turns (≈54° each way in Pico-8's turns-based trig convention), `rope_freq=0.425` (a ~2.35-second full swing period — 15% slower than the first pass's `0.5`/2.0s, per a play-test request; verified against a measured period from the actual sine crossings, not just the input constant). The bob's screen position is the anchor offset by `(rope_l*sin(theta), rope_l*cos(theta))`, `rope_l=20`. This is driven purely by elapsed time, not physics integration — no velocity state, no player input, nothing to get stuck at rest.
- **Grab**: this is *not* a check against the bob's exact moving position — an earlier version required the player to be within 14px on both axes of wherever the bob currently was, which turned out to be too fragile to hit reliably in practice ("player doesn't grab it"). Grabbing now works the same way the ladder does: stand (or jump) so the player's centre is within 16px of the rope's anchor column, anywhere in the vertical band between the two rows the rope's pair connects (with an 8px margin top and bottom), and press up. Grab succeeds immediately, regardless of what phase the swing is currently in — the player attaches at whatever position the bob happens to be in that frame, which may be a few pixels from where they were standing, read as "catching" the rope rather than a precise mid-air interception. A 20-trial harness (random levels, fixed approach position, holding up) grabbed successfully every time, in 1 frame in the worst case.
- **While attached**: the player's position is set to the same time-driven formula every frame, so they move with the rope exactly as if standing on it — verified to keep moving frame to frame while attached, not freeze once grabbed.
- **Release**: fire or jump button lets go. `pvx`/`pvy` are set from the swing's actual frame-to-frame pixel displacement at the moment of release (last frame's position minus this frame's), which is exactly the bob's instantaneous velocity, no separate formula or guessed scale constant needed. `pvx` then decays as an ordinary horizontal-momentum term added on top of button input in the normal movement code, going through the same box-collision check as walking, so a mid-air release into a box is still blocked correctly.
- After release, normal jump/fall physics apply. Landing on the far platform's tile range is a successful crossing; missing it means falling through to whatever's below (same as any other gap — no separate fall damage).

### Prize spawn (gun & bottle)

A single shared spawn timer (`prize_int=450`, 15s at 30fps — a starting heuristic, not measured) picks a random column across all 10 rows that's currently a platform tile and not boxed (so a prize is never unreachable under a box or floating over a gap), then rolls 50/50 gun vs. bottle, and for a bottle a further 50/50 green (`good`) vs. red. Both are placeholder odds; no tuning signal yet on whether they should be weighted. A 1,000-trial harness confirmed every spawn lands on a valid non-boxed platform tile.

### Gun

- Picking up the gun prize sets `gun_t = gun_dur = 300` (10s at 30fps) and `gun_cd` (fire cooldown) to 0.
- While `gun_t > 0`, `gun_t` counts down every frame; when it reaches 0 the gun is unequipped. Firing (only when `gun_t > 0` and `gun_cd <= 0`) spawns a shot travelling in the player's facing direction (tracked via a `facing` variable, set to ±1 whenever left/right is pressed, independent of the gun), resets `gun_cd` to `gun_cd_max=6` frames (rate limit, no ammo count).
- Each shot moves at `shot_spd=4` px/frame and is removed on hitting the first hazard it touches (destroying it, `score += 10`) or leaving the level's horizontal bounds. Shots don't collide with platforms, boxes, or ladders — they fly straight through solids, a deliberate simplification (nothing in the design calls for shots to be blocked by terrain, and it keeps the collision check to one loop over hazards).
- A harness confirmed: pickup sets the timer, a shot in range destroys a hazard and adds exactly 10 score, and the cooldown actually limits fire rate (4 shots in 30 frames of held fire, not 30).

### Bottle

- Green (`good=true`) adds 1 life, no cap. Red (`good=false`) removes 1 life, triggering game over at 0 same as a hazard hit. Verified with a harness for both cases.
- No visual/sound feedback yet beyond the life-count change itself (a flash or chime is Phase 6 polish, same as the hazard-hit flash already has and the bottle pickup doesn't yet).

### Difficulty ramp

Per level `n` (starting at 1):

- Gap density: `min(0.35, 0.15 + 0.02 * (n - 1))`.
- Hazard spawn interval (frames): `max(30, 90 - 5 * (n - 1))`.
- Hazard fall/roll speed: `base_speed * min(2, 1 + 0.1 * (n - 1))`.

These are starting heuristics, not measured; expect to retune after the first few play tests, the same way game 3's and game 4's numeric constants were adjusted post-implementation.

### Visuals

Twelve 8x8 sprites replace the earlier phases' flat `rectfill` placeholders: player stand/walk (2 frames, `spr()`'s `flip_x` handles left-facing), platform beam, box, and one each for tumbleweed/barrel/hazard bottle/wagon wheel/gun/green bottle/red bottle/finish button, at sheet indices 1-12. Authored as [`tools/sprites`](../tools/sprites) hex-grid def files (`g5_*.txt`, matching game 4's `g4_*` naming), rendered to a combined PNG via `sprite_tool.py sheet` and visually reviewed before patching into the cart with `sprite_tool.py patch` — this project's sprite tool supports an actual visual preview step, so these weren't authored blind. Ladders and the rope stay as procedural `line()` draws rather than sprites; both already read clearly as rungs/a taut line and don't need pixel art. The player's walk frame swaps in at a fixed 8Hz while `btn(0)`/`btn(1)`/climbing is true, otherwise the stand frame holds; invincibility after a hazard hit now flickers by skipping the draw call entirely on alternate frames (a blink) rather than swapping colour, since a flat colour swap doesn't read the same way on top of real pixel art.

### Sound

Thirteen SFX slots (0-12: jump, ladder step, rope grab, rope release, hazard hit, green bottle, red bottle, gun pickup, gun shot, gun expiring warning, hazard destroyed, level clear, game over) were authored by direct encoding rather than by ear — this machine can't play or hear Pico-8 audio, so pitch/waveform/volume/effect values were chosen by construction (matching the character each event calls for: noise waveform for hits/pops, square/triangle for clean blips, ascending/descending runs for level-clear/game-over mirroring game 3's precedent) and validated only structurally (correct 168-character line length, correct field encoding cross-checked byte-for-byte against game 3's known-working `__sfx__` data). Same caveat as every other game in this jam that reached this phase: flag anything that sounds wrong at the first real play test, since nothing here has actually been heard yet. The climb-step tick fires roughly every 6 frames while climbing (about every 2 rendered rungs, since rungs are drawn every 3px and climb speed is 1px/frame) rather than exactly once per rung — a deliberate approximation, not a bug, since a rung-mocked trigger would need to track distance climbed rather than just a frame-based modulo.

## Token budget

This is the most system-dense game in the jam so far: ramp/tile generation, a scrolling camera, rolling hazard AI, pendulum rope physics, a timed weapon, and a two-tier item system (hazards plus two prize types) all in one cart. The camera itself is cheap (one clamped subtraction applied at draw time via Pico-8's `camera()`), and the jump from 6 to 10 rows is just larger loop bounds over the same per-row logic, so neither should meaningfully move the token count on their own. Budget comparably to game 4's arc-shooter complexity (which landed around 1,400 tokens for its core systems alone, well under the ~8,192 cap) rather than game 3's flatter design. Lean hard on [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for the shared title card and screen-flash helpers; the ramp/tile/hazard/rope logic here is novel to this game and isn't in `lib/` yet. Represent tile types as small integers in a flat per-row array (not per-tile objects) and hazard type as a flat sprite/colour lookup indexed by a type id, following the same flat-array-by-id approach game 3 used for its item colour tables.
