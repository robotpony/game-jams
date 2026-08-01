# #1 Maze Runner

A simple maze game. Watch out for the traps and monsters! Based on a game I wrote in 1981.

## Game overview

The game looks like an Atari 2600 game. Colours, sprites, and fonts should approximate the Atari 2600 aesthetic using Pico-8's palette.

A maze game with a 60-second countdown timer per level. The player explores a single-screen maze collecting treasures and avoiding traps before finding the exit.

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Shared jam title card: colour-swatch strip, "'26 WARPED GAME JAM", "#1", blinking "press x to start" prompt | Startup | Any button → Game |
| Game | 16×15 maze, HUD (score, level, timer) | Title, or Transitioning complete | Exit or teleport collected → Transitioning; score < 0 or timer = 0 → Game over |
| Transitioning | HUD stays visible; 18-frame black/white flicker over the maze | Exit or teleport collected | Flicker complete → Game, next level loaded |
| Game over | Final score | Score < 0, or timer reaches 0 | Any button → Title |

## Maze

- Fits on one screen, 16×15 cells. No scrolling.
- Generated procedurally using a seeded algorithm (same seed = same maze).
- Must have at least one guaranteed path from start to exit.
- Always contains exactly 1 exit.
- Items (traps, treasures, teleports, ammo) are placed randomly, up to 2 of each per level, onto dead-end cells. If a level has fewer dead ends than the number of items rolled, the excess items are dropped for that level rather than placed elsewhere (see [BUGS.md 1.2](../BUGS.md#1--maze-game) for the same shortfall applied to the exit tile).

## Player

- White humanoid drawn with primitives: 2×2 head, 2×3 body, single arm pixel indicating facing direction, two leg pixels.
- Faces the direction of last movement (4 orientations: up, down, left, right).
- Moves in 4 directions. Cannot move through walls.
- No lives or health. Score is the primary resource; ammo is a secondary resource for fighting monsters (see Monsters below).
- Starting score: 0. Score carries over between levels.
- Starting ammo: 10. Ammo carries over between levels.

## Items

| Item | Effect | Visual feedback |
| ---- | ------ | --------------- |
| Trap | -1 point | Red screen flash |
| Treasure | +2 points; timer resets to 60s | Green screen flash |
| Teleport | Jump to `current_seed + rnd(1–9)`; player appears at the first teleport tile in the destination level | (none specified) |
| Exit | Advance to `current_seed + 1`; timer resets to 60s; player appears at start tile | (none specified) |
| Ammo | +2 shots | Purple screen flash |

Items are consumed on contact and become floor tiles.

## Monsters

- 1-3 per level, placed on dead-end cells, picked independently of item placement so monster count doesn't compete with (or get starved by) how many items rolled that level. A monster can occasionally share a dead-end cell with an item.
- Patrol the corridor leading away from their spawn cell, up to 8 cells, turning back at a junction, another dead end, or the 8-cell cap, whichever comes first.
- Move one cell at a time, pausing a random 8-17 frames between steps, so the patrol isn't a fixed, learnable cycle.
- Non-blocking: the player walks through a monster's tile freely. Since the maze is a perfect maze (recursive backtracking produces exactly one path between any two cells), a solid obstacle could permanently block the only route; a non-blocking monster can't.
- Contact with a live monster resets the player to the start tile. Score and timer are unaffected.

### Shooting

- The player carries ammo (starts each game with 10, +1 per monster killed, +2 per ammo pickup) and fires in their facing direction with the O button.
- A shot travels until it hits a wall (disappears) or a monster (monster is defeated, shot disappears).
- A defeated monster respawns at a different dead-end cell 3 seconds later.
- Firing has a short cooldown (~0.5s) and costs 1 ammo; nothing happens if ammo is 0.

## Timer

- Starts at 60 seconds at the beginning of each level.
- Also resets to 60 seconds when the player collects a treasure.
- Counts down in real time. Reaching 0 ends the game.

## Game over conditions

- Score goes negative (below 0).
- Timer reaches 0.

## Progression

- First level seed is a random number chosen at game start.
- Sequential exits advance to `current_seed + 1`.
- Teleports jump to `current_seed + rnd(1–9)` (offset is 1–9, never 0, so the player always moves to a different level).

## Sound

Simple beeps approximating Atari 2600 audio. Events that need sound: trap hit, treasure collected, teleport activated, exit reached, shot fired. Movement sound is optional. Monster contact reuses the trap hit cue; ammo pickup and defeating a monster reuse the treasure cue.

## Tile / sprite visuals

All tiles are 8×8 pixels, drawn with primitives. Atari 2600-approximated colours using Pico-8's palette.

| Tile | Colour | Visual |
| ---- | ------ | ------ |
| Floor | Black (0) | Empty |
| Wall | Dark blue (1) with grey (5) highlight pixels | Solid block |
| Start | Green (11) | 3-sided box open right, arrow pointing out |
| Exit | Orange (9) | 3-sided box open left, arrow pointing in |
| Trap | Red (8) | X mark |
| Treasure | Yellow (10) | Diamond outline |
| Teleport | Cyan (12) | Two concentric circles |
| Ammo | Purple (2) | Vertical bar with two side ticks, bullet-like |
| Monster | Dark red (13) | Filled circle blob with two white eye pixels |
| Shot | White (7) | Small filled dot, travels from the player outward |

Start and exit are visual inverses: start is a box you leave (arrow out), exit is a box you enter (arrow in).
