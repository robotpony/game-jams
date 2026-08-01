# 5 To The Top

A vertical platform puzzler where the player climbs randomized wild-west ramps to reach the top, dodging rolling hazards on the way up.

## Details

This is a puzzle/platformer built using Claude and Pico-8, a side-view re-imagining of early-80s climbing games (Donkey Kong and its era) with a wild-west theme layered on top. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts approximate the Atari 2600 aesthetic using Pico-8's palette; wood tones (brown/tan) carry the wild-west setting.

## Game overview

The player climbs from the ground to a finish platform at the top of the screen, using a randomized arrangement of platforms, ladders, box obstacles, gaps, and a rope. Wild-west hazards (tumbleweed, barrels, bottles, wagon wheels) spawn at the top and roll down the platforms toward the bottom, falling through any gap they reach; touching one costs the player a life. Two prize types spawn periodically: a gun (temporary, destroys hazards on contact with a shot) and a bottle (green heals, red hurts).

Reaching the finish platform's button advances to a new randomized level and increases the pace: hazards spawn more often, roll faster, and levels carry more gaps. There's no final level; the game is an endless climb that ends when the player runs out of lives, so the goal is score and how many levels can be cleared before that happens.

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Shared jam title card: colour-swatch strip, "'26 WARPED GAME JAM", "5 TO THE TOP", blinking start prompt | Startup | Any button → Game |
| Game | Scrolling playfield (10 platform rows, ladders/boxes/gaps/rope, falling hazards), player, fixed HUD | Title, or Level transition complete | Lives hit 0 → End; finish button reached → Level transition |
| Level transition | HUD stays visible; brief flicker over the playfield, next level number shown | Finish button reached | Flicker complete → Game, next randomized level loaded |
| End | "GAME OVER", final score, levels cleared | Game | Any button → Title |

## Core mechanic: ramp ascent, rolling hazards, and rope swings

Each level has 10 platform rows stacked above the ground: Platform 1 (lowest) through Platform 9, then the Finish platform (topmost, holding the level-advance button). That's up from a 3-platform draft that played too short and a since-abandoned 5-platform draft that packed rows too tightly together (less than 2x the player sprite's height between them); the climb gap between rows is now a fixed 24px, 3x the player's 8px sprite height, which is why the level no longer fits on one screen and the camera scrolls vertically to follow the player, keeping them roughly centred and clamped to the level's top and bottom. Each row is 16 tiles wide (8px each, spanning the 128px screen width) and is randomly generated as a mix of:

- **Platform tiles** — walkable ground for that row.
- **Gap tiles** — no floor; the player must jump over them, hazards fall through them to the row below. Gaps also do the job an earlier draft gave a dedicated "chute lane" hazard column; that column was cut as redundant once ordinary gaps already let hazards fall through.
- **Ladder** — a vertical connector between two rows at the same column; hold up/down to climb. Every level generates one ladder for every pair of adjacent rows (ground↔platform1, platform1↔platform2, ... platform9↔finish, 10 pairs in all), so a level always has a full ladder path from ground to finish.
- **Box** — a static obstacle sitting on top of a platform tile within a row; the player is blocked by its side and has to jump to get on top of it or clear over it, the same way a gap has to be jumped rather than walked into. It never sits on a ladder's column, so it can't block the climb path, and standing on one doesn't give enough extra height to skip a row — ladders are still the only way up.

A player can also fall through a gap tile at the very left or right edge of a row (column 0 or 15) exactly like an interior gap — there's no invisible wall at the level's horizontal edges, only the tile roll itself.

**Rope**: exactly one rope anchor per level, positioned over the gap between two rows as an optional faster crossing (the ladder is always the guaranteed route; the rope is purely a shortcut). It swings back and forth continuously and automatically, whether or not the player is near it, on a slow (~2.35s) cycle. To grab it, get close to the rope's column (about 2 tiles either side) at roughly the height of either row the gap connects, and press up — the catch works regardless of what point the swing is at, so it's forgiving rather than a precise mid-air interception. Pressing ❎/🅾️ releases it, launching in whatever direction the swing was moving at that instant. Timing the release wrong means missing the far platform and dropping to whatever's below, same as falling through any other gap; there's no separate fall damage, so a missed swing costs position, not a life.

**Hazards**: tumbleweed, barrels, bottles (hazard variant), and wagon wheels spawn at the top of the level (not the top of the current screen — see DESIGN.md's note on this) at a random column and fall. All four move identically (roll speed, spawn rate) and differ only in sprite; only the collision box, not the behaviour, changes anything. On reaching a platform tile, a hazard rolls in a fixed direction (chosen at spawn); it reverses direction on hitting a box obstacle or the level's left/right edge, and falls through when it reaches a gap tile. Touching the player costs 1 life, with a brief invincibility window afterward so one hazard can't remove multiple lives in one pass.

## Player

- **Move**: left/right to walk, ❎ to jump, 🅾️ to fire (only while the gun is active).
- **Climb**: up/down while on a ladder. Get near the rope's column (about 2 tiles either side, anywhere between the two rows it connects) and press up to grab it — it's always swinging, but the grab itself isn't timing-sensitive, just proximity; ❎/🅾️ releases it.
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
| Ladder | Orange | 9 | Vertical rungs over a beam gap |
| Box | Dark brown | 4, with white (7) outline | Obstacle sitting on top of a platform tile, distinct outline from a plain beam |
| Gap | (background) | 0 | No tile; black background shows through |
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
