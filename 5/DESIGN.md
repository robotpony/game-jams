# 5 To The Top — Design

Pre-implementation technical design. See [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md) for what this document covers versus [README.md](README.md) and [CLAUDE.md](CLAUDE.md).

## Screen layout (128×128)

```
y=0-7      hazard spawn band: items enter here at a random column
y=8-15     row 3 (finish): 8px platform row, holds the level-advance button
y=16-31    climb gap (16px): ladder/stairs/box/rope for row3↔row2
y=32-39    row 2 (platform 3): 8px platform row
y=40-55    climb gap (16px): row2↔row1
y=56-63    row 1 (platform 2): 8px platform row
y=64-79    climb gap (16px): row1↔row0
y=80-87    row 0 (platform 1): 8px platform row
y=88-103   climb gap (16px): row0↔ground
y=104-111  ground row: player start, not randomized (always solid, no hazards below it)
y=112-127  HUD line (16px: lives | level | score)
```

- Four platform rows (`y = 8, 32, 56, 80`), each 8px tall, 16 columns of 8px tiles spanning x=0–127.
- 16px climb gaps between consecutive rows (and between row 0 and ground) hold that row pair's connector, if any.
- Ground row (`y=104`) is fixed, always solid, never randomized; the player starts here every level.
- HUD: `y=112–127`, left-aligned lives (numeric), centred level number, right-aligned score — matches the project's left/center/right HUD convention (see [`../3/DESIGN.md`](../3/DESIGN.md)).

## Palette

| Element | Colour | Index |
| ------- | ------ | ----- |
| Background | Black | 0 |
| Platform / beam | Brown | 4 |
| Ladder rungs | Tan | 9 |
| Stairs / box outline | White | 7 |
| Chute lane marker | Grey | 6 |
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

Each row (0–3, bottom to top of the four platform rows) is a 16-element array of tile types, generated independently per level:

1. Pick one column (0–15) as the level's **chute lane**. That column is forced to `gap` in all four rows.
2. For each row, for each non-chute column, roll `gap` vs `platform` weighted by the level's gap density (see Progression below; starts around 15%, rises with level, capped around 35%).
3. For each pair of adjacent rows (ground↔row0, row0↔row1, row1↔row2, row2↔row3), pick one non-chute column that is `platform` in both rows and mark it as a **connector**: roughly 2-in-3 chance ladder, 1-in-3 chance stairs/box. If no shared-platform column exists between a pair after step 2's roll, force one column in each of the two rows to `platform` and use it as the connector, so every level is completable by construction.
4. Pick one gap (a row-pair and column, excluding the chute lane and any generated connector) to hold the level's single **rope anchor**.

This guarantees a solid connector column between every pair of adjacent rows, so vertical progress from ground to finish never strictly requires the rope. It does not by itself guarantee the player can *walk* from one row's landing point to that row's connector column without a jump-worthy run of gap tiles in between — with gap density capped at 35% (see Progression), a long unbroken run of gaps between connectors is possible though statistically rare. A 2,000-trial simulation of the generation algorithm alone (chute/connector placement, no jump-range check) found zero cases of a missing connector or a connector landing on the chute column, but it can't rule out an occasional hard-to-cross row; this is exactly what Phase 1's manual "generate several levels and confirm a path exists" verify step in [PLAN.md](PLAN.md) is for. If playtesting finds it's a real problem, harden step 2 or 3 with a same-row reachability check (e.g. no run of gap tiles longer than the player's jump range) rather than just widening jump distance.

### Hazard spawn and movement

- Spawn timer counts down; on reaching 0, a hazard is added at `y=0`, a random column (any column, including the chute lane — landing in it is what makes the chute a real threat), a random type (tumbleweed/barrel/hazard-bottle/wagon-wheel, equal weight, sprite-only difference), and a random roll direction (left/right).
- Each frame, a hazard falls at the current global fall speed until its `y` reaches a row's band.
- On reaching a row: if its column is `gap` in that row, it keeps falling into the next row's band (or off the bottom of the screen, despawning, if it was already at row 0). If its column is `platform`, it rolls horizontally in its assigned direction at a fixed roll speed until it reaches a column that's `gap` in that row, then resumes falling.
- Collision with the player (bounding-box overlap) costs 1 life and starts a short invincibility window (roughly 1s) during which further hazard contact is ignored, so a single hazard graze can't chain multiple hits.

### Rope swing

- The rope is a single point anchor at the top of its assigned gap. The player grabs it by moving into the adjacent tile and pressing up (or jumping toward it).
- While grabbed, an angle `theta` (0 = hanging straight down) evolves via simple harmonic motion: `theta_v += -k * sin(theta)`, `theta += theta_v`, where `k` is a small tuning constant. The player's screen position is the anchor point offset by `(L*sin(theta), L*cos(theta))` for a fixed rope length `L`.
- Left/right input nudges `theta_v` to let the player pump the swing; the fire/jump button releases the grab, launching the player with horizontal velocity proportional to `theta_v` at the moment of release.
- After release, normal jump/fall physics apply. Landing on the far platform's tile range is a successful crossing; missing it means falling through to whatever's below (same as any other gap — no separate fall damage).

### Gun

- Picking up the gun prize sets `gun_t = 300` (10s at 30fps) and a `gun_cd` (fire cooldown) at 0.
- While `gun_t > 0`, `gun_t` counts down every frame; when it reaches 0 the gun is unequipped.
- Firing (only when `gun_t > 0` and `gun_cd == 0`) spawns a shot travelling in the player's facing direction, resets `gun_cd` to a small fixed value (rate limit, no ammo count), and the shot is removed on hitting the first hazard it touches (destroying it, +10 score) or leaving the screen.

### Difficulty ramp

Per level `n` (starting at 1):

- Gap density: `min(0.35, 0.15 + 0.02 * (n - 1))`.
- Hazard spawn interval (frames): `max(30, 90 - 5 * (n - 1))`.
- Hazard fall/roll speed: `base_speed * min(2, 1 + 0.1 * (n - 1))`.

These are starting heuristics, not measured; expect to retune after the first few play tests, the same way game 3's and game 4's numeric constants were adjusted post-implementation.

## Token budget

This is the most system-dense game in the jam so far: ramp/tile generation, rolling hazard AI, pendulum rope physics, a timed weapon, and a two-tier item system (hazards plus two prize types) all in one cart. Budget comparably to game 4's arc-shooter complexity (which landed around 1,400 tokens for its core systems alone, well under the ~8,192 cap) rather than game 3's flatter design. Lean hard on [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for the shared title card and screen-flash helpers; the ramp/tile/hazard/rope logic here is novel to this game and isn't in `lib/` yet. Represent tile types as small integers in a flat per-row array (not per-tile objects) and hazard type as a flat sprite/colour lookup indexed by a type id, following the same flat-array-by-id approach game 3 used for its item colour tables.
