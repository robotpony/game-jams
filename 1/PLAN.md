# Plan

All four phases complete.

## Phase 1: Maze + navigation

- [x] Maze generation using recursive backtracking, seeded (same seed = same maze)
- [x] Player spawns at start tile, moves with arrow keys, blocked by walls
- [x] Player sprite faces direction of movement
- [x] HUD stub: score, level number, timer labels
- [x] Verify: maze is always solvable, wall collision works

## Phase 2: Game logic

- [x] Place items in maze (up to 2 traps, 2 treasures, 2 teleports, 1 exit), preferring dead ends
- [x] Trap: -1 score, red screen flash; game over if score goes negative
- [x] Treasure: +2 score, green screen flash, timer resets to 60s
- [x] Exit: advance to next level (seed + 1), timer resets to 60s, player appears at start tile
- [x] Teleport: jump to seed + rnd(1–9), player appears at first teleport tile in destination level
- [x] Timer counts down in real time; reaching 0 ends the game
- [x] Score carries over between levels

## Phase 3: Screens

- [x] Title screen: "This is #1, a test game", prompt to start (later retrofitted to the shared jam title card, see `1/CLAUDE.md`)
- [x] Game over screen: shows final score, any button returns to title
- [x] Level transitions: 18-frame black/white flicker between levels

## Phase 4: Visuals + sound

- [x] Primitive-drawn tiles: player, wall, floor, trap, treasure, teleport, start, exit
- [x] Start tile: 3-sided green box, arrow pointing out
- [x] Exit tile: 3-sided orange box, arrow pointing in
- [x] Atari 2600-approximated colour palette applied throughout
- [x] SFX for trap, treasure, teleport, and exit events
- [x] HUD finalized: score left, level number center, timer right
