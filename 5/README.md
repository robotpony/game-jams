# 5 To The Top

A vertical platform puzzler where the player climbs randomized wild-west ramps to reach the top, dodging rolling hazards on the way up.

## Details

This is a puzzle/platformer built using Claude and Pico-8, a side-view re-imagining of early-80s climbing games (Donkey Kong and its era) with a wild-west theme layered on top. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts approximate the Atari 2600 aesthetic using Pico-8's palette; wood tones (brown/tan) carry the wild-west setting.

## Game overview

The player climbs from the ground to a finish platform at the top of the screen, using a randomized arrangement of platforms, ladders, stairs, boxes, gaps, and a rope. Wild-west hazards (tumbleweed, barrels, bottles, wagon wheels) spawn at the top and roll down the platforms toward the bottom, falling through any gap they reach; touching one costs the player a life. Two prize types spawn periodically: a gun (temporary, destroys hazards on contact with a shot) and a bottle (green heals, red hurts).

Reaching the finish platform's button advances to a new randomized level and increases the pace: hazards spawn more often, roll faster, and levels carry more gaps. There's no final level; the game is an endless climb that ends when the player runs out of lives, so the goal is score and how many levels can be cleared before that happens.

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Shared jam title card: colour-swatch strip, "'26 WARPED GAME JAM", "5 TO THE TOP", blinking start prompt | Startup | Any button → Game |
| Game | Playfield (4 platform rows, ladders/stairs/boxes/gaps/rope, falling hazards), player, HUD | Title, or Level transition complete | Lives hit 0 → End; finish button reached → Level transition |
| Level transition | HUD stays visible; brief flicker over the playfield, next level number shown | Finish button reached | Flicker complete → Game, next randomized level loaded |
| End | "GAME OVER", final score, levels cleared | Game | Any button → Title |

## Core mechanic: ramp ascent, rolling hazards, and rope swings

Each level has 4 platform rows stacked above the ground: Platform 1 (lowest), Platform 2, Platform 3, and the Finish platform (topmost, holding the level-advance button). Each row is 16 tiles wide (8px each, spanning the 128px screen) and is randomly generated as a mix of:

- **Platform tiles** — walkable ground for that row.
- **Gap tiles** — no floor; the player must jump over them, hazards fall through them to the row below.
- **Ladder** — a vertical connector between two rows at the same column; hold up/down to climb.
- **Stairs / box** — an alternate connector between two rows; the player walks or jumps up onto it directly, no climb input needed (distinct from a ladder, which requires holding a direction to ascend).
- **Chute lane** — exactly one column per level is a gap tile in every row, top to bottom. Hazards spawning or rolling into this column free-fall straight to the bottom instead of rolling; it's a fast lane the player has to watch for, not a route the player can use.

Level generation always guarantees at least one ladder or stairs/box connector between each pair of adjacent rows (in a column other than the chute lane), so every randomized level is completable without the rope.

**Rope**: exactly one rope anchor per level, positioned over a gap between two rows as an optional faster crossing. Grabbing it starts a pendulum swing (angle moves toward vertical, accelerating away from centre — a simple harmonic swing); the player releases mid-swing to launch across the gap. Timing the release wrong means missing the far platform and dropping to whatever's below, same as falling through any other gap; there's no separate fall damage, so a missed swing costs position, not a life.

**Hazards**: tumbleweed, barrels, bottles (hazard variant), and wagon wheels spawn at the top of the screen at a random column and fall. All four move identically (roll speed, spawn rate) and differ only in sprite; only the collision box, not the behaviour, changes anything. On reaching a platform tile, a hazard rolls in a fixed direction (chosen at spawn) until it reaches a gap or the chute lane, then keeps falling. Touching the player costs 1 life, with a brief invincibility window afterward so one hazard can't remove multiple lives in one pass.

## Player

- **Move**: left/right to walk, ❎ to jump, 🅾️ to fire (only while the gun is active).
- **Climb**: up/down while on a ladder or a rope-adjacent tile (up/down also controls the rope's release timing while swinging).
- **Lives**: start at 3, no upper cap; green bottles can push the count arbitrarily high, so the HUD shows lives as a number rather than a fixed row of icons.
- **Score**: +100 per level cleared (finish button reached), +10 per hazard destroyed with the gun. Carries across levels and resets only on a new game from Title, not on level advance.

## Items

| Item | Effect | Visual feedback |
| ---- | ------ | ---------------- |
| Tumbleweed | Hazard: touching it costs 1 life | Brief player flash + hit sound |
| Barrel | Hazard: touching it costs 1 life | Brief player flash + hit sound |
| Hazard bottle | Hazard: touching it costs 1 life | Brief player flash + hit sound |
| Wagon wheel | Hazard: touching it costs 1 life | Brief player flash + hit sound |
| Gun (prize) | Collect to enable firing for 10 seconds (300 frames); shots destroy the first hazard they hit, +10 score each | Player sprite holds the gun; HUD shows a countdown |
| Bottle, green (prize) | +1 life, no cap | Green flash, rising chime |
| Bottle, red (prize) | -1 life | Red flash, low buzz |

Hazard bottles and prize bottles use different colours (hazard bottles are amber/glass-brown; prize bottles are bright green or red) so they read as different objects despite the shared name.

## Game over conditions

- Lives reach 0 → End screen ("GAME OVER"), showing final score and levels cleared.
- No win condition: the climb is endless, and difficulty keeps ramping with each level cleared (see Progression).

## Progression

Each time the player reaches the finish button, the level counter increments, the layout is regenerated, and difficulty increases along three axes:

- **Hazard spawn rate**: interval shortens with level (more hazards on screen at once at higher levels).
- **Hazard roll/fall speed**: increases with level, capped at roughly 2x the starting speed.
- **Gap density**: later levels bias platform-tile generation toward more gap tiles per row (level generation's one-guaranteed-connector rule still applies, so the level stays completable).

Exact per-level formulas are tuning constants, tracked in [DESIGN.md](DESIGN.md).

## Sound

| Event | Description |
| ----- | ------------ |
| Jump | Short percussive blip |
| Climb step (ladder) | Soft tick, one per rung |
| Rope grab | Low creak |
| Rope release | Short whoosh |
| Hazard hit (lose life) | Descending buzz |
| Green bottle pickup | Rising chime |
| Red bottle pickup | Low buzz |
| Gun pickup | Bright ascending blip |
| Gun shot | Short percussive crack |
| Gun expiring (last ~1s) | Two quick warning beeps |
| Hazard destroyed by gun | Small pop |
| Finish button / level clear | Ascending 3-note run |
| Game over | Descending 3-note run |

## Tile / sprite visuals

| Tile / sprite | Colour | Index | Description |
| ------------- | ------ | ----- | ------------ |
| Platform (beam) | Brown | 4 | Solid wood-plank beam, 8px tall |
| Ladder | Tan | 9 | Vertical rungs over a beam gap |
| Stairs / box | Dark brown | 4, with white (7) outline | Raised step block, distinct outline from a plain beam |
| Gap | (background) | 0 | No tile; black background shows through |
| Chute lane marker | Grey | 6 | Faint diagonal stripe over the gap column, warns of the fast hazard lane |
| Rope | Yellow | 10 | Single vertical line from its anchor point |
| Finish button | Gold | 10 (flashing with 7) | Small block on the finish platform, flashes to draw the eye |
| Player | Red shirt (8), blue jeans (12), tan skin (15) | — | Small cowboy sprite, run/jump/climb frames |
| Tumbleweed | Tan | 4 | Round, cross-hatched sprite |
| Barrel | Brown | 4, with black (0) rings | Classic barrel silhouette |
| Hazard bottle | Amber | 9 | Bottle silhouette, glass-brown fill |
| Wagon wheel | Grey | 6, brown (4) hub | Circle with spokes |
| Gun (prize) | Silver | 6, brown (4) grip | Small pistol sprite |
| Bottle, green (prize) | Green | 11 | Same bottle silhouette as the hazard bottle, green fill |
| Bottle, red (prize) | Red | 8 | Same bottle silhouette as the hazard bottle, red fill |
