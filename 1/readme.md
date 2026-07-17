# 1 README

This is a simple game built using Claude and Pico-8.

The game looks like an Atari 2600 game. Colours, sprites, and fonts should approximate the Atari 2600 aesthetic using Pico-8's palette.

## Game overview

A maze game with a 60-second countdown timer per level. The player explores a single-screen maze collecting treasures and avoiding traps before finding the exit.

## Screens

**Title screen**: Retro style. Shows "This is #1, a test game" with a blinking "press x to start" prompt and movement instructions. Start here on launch.

**Game screen**: The maze occupies a 16×15 cell grid (128×120px). The HUD is a single line at the bottom (y=120–127): score on the left, level number in the center, timer on the right.

**Transitioning**: Triggered by exit or teleport. An 18-frame black/white flicker, then the next level loads. The HUD remains visible.

**Game over**: Triggered when score goes negative or timer reaches 0. Shows the final score. Press any button to return to the title screen.

## Maze

- Fits on one screen, 16×15 cells. No scrolling.
- Generated procedurally using a seeded algorithm (same seed = same maze).
- Must have at least one guaranteed path from start to exit.
- Always contains exactly 1 exit.
- Items (traps, treasures, teleports) are placed randomly, up to 2 of each per level. Items prefer dead ends; if no dead ends exist they may be placed on the critical path.

## Player

- White humanoid drawn with primitives: 2×2 head, 2×3 body, single arm pixel indicating facing direction, two leg pixels.
- Faces the direction of last movement (4 orientations: up, down, left, right).
- Moves in 4 directions. Cannot move through walls.
- No lives or health. Score is the only resource.
- Starting score: 0. Score carries over between levels.

## Items

| Item | Effect | Visual feedback |
| ---- | ------ | --------------- |
| Trap | -1 point | Red screen flash |
| Treasure | +2 points; timer resets to 60s | Green screen flash |
| Teleport | Jump to `current_seed + rnd(1–9)`; player appears at the first teleport tile in the destination level | (none specified) |
| Exit | Advance to `current_seed + 1`; timer resets to 60s; player appears at start tile | (none specified) |

Items are consumed on contact and become floor tiles.

## Timer

- Starts at 60 seconds at the beginning of each level.
- Also resets to 60 seconds when the player collects a treasure.
- Counts down in real time. Reaching 0 ends the game.

## Game over conditions

- Score goes negative (below 0).
- Timer reaches 0.

## Level seeding

- First level seed is a random number chosen at game start.
- Sequential exits advance to `current_seed + 1`.
- Teleports jump to `current_seed + rnd(1–9)` (offset is 1–9, never 0, so the player always moves to a different level).

## Sound

Simple beeps approximating Atari 2600 audio. Events that need sound: trap hit, treasure collected, teleport activated, exit reached. Movement sound is optional.

## Tile visuals

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

Start and exit are visual inverses: start is a box you leave (arrow out), exit is a box you enter (arrow in).
