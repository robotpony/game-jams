# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "1" — a retro maze game with Atari 2600 aesthetics. The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md). Output is a single `.p8` cartridge file.

This game shipped before `SPEC-FORMAT.md`'s DESIGN.md convention existed, so there's no DESIGN.md here; the Architecture section below is both the technical design and the as-built record.

## Development

Pico-8 has no build system. The workflow is:

- Edit the `.p8` file in an external editor or inside Pico-8's built-in editor
- Run with `pico8 -run 1.p8` (requires Pico-8 installed)
- Or open Pico-8, then `load 1.p8` and press Ctrl+R to run

There are no tests, linters, or package managers.

## Pico-8 Constraints

These constraints shape every implementation decision:

- **Token limit**: ~8,192 tokens total (code is compressed; count aggressively)
- **Display**: 128×128 pixels, 16-colour palette
- **Sprites**: 8×8 pixels each, 256 slots in the sprite sheet
- **Map**: 128×64 cells, shared memory with the bottom half of the sprite sheet
- **Colours**: Pico-8 has its own 16-colour palette — to approximate Atari 2600, use black (0), white (7), red (8), orange (9), yellow (10), green (11), dark green (3), teal (12), sky blue (6), dark blue (5), purple (2), dark red (13)
- **Sound**: 64 SFX slots, 4 channels
- **Lua variant**: Pico-8 Lua omits some standard library functions. No `string.format` on older versions; use `tostr()`, `tonum()`, `sub()`, `#str` for strings

## Architecture

The game should follow the standard Pico-8 callback structure in a single `1.p8` file:

```lua  
_init()   -- called once on startup: seed RNG, generate first level
_update() -- called 30fps: handle input, move player, check collisions
_draw()   -- called 30fps: clear screen, draw map, player, HUD
```

### Key systems

**Maze generation** — Recursive backtracking (depth-first search) on a grid. Seed with `srand(lseed)` before generation so the same seed always produces the same maze. The maze array is a flat table indexed `y*mw+x`.

**Level seeding** — `lseed = flr(rnd(32767))` on new game. Sequential exits: `lseed+1`. Teleports: `lseed + flr(rnd(9)) + 1`.

**Map layout** — Tile type IDs stored in the `maze` table (not Pico-8 map tiles). Tile IDs: 0=floor, 1=wall, 2=start, 3=exit, 4=trap, 5=treasure, 6=teleport. Player is drawn with primitives, not stored in the maze.

**Collision** — `mg(x,y)` reads a tile (returns 1 for out-of-bounds). Check before moving; wall tiles block, item tiles trigger `handle_tile()` then become floor.

**HUD** — Bottom strip (y=120–127): score left, level number centered, timer right. Drawn every frame over the game area.

**Screen flash** — On item pickup, set `flash_t` (frames) and `flash_c` (colour). In `_draw()` during playing state, if `flash_t > 0`, fill the game area with `flash_c` instead of drawing the maze, then decrement.

### Game states

| `gs` | Name | Triggered by |
| ---- | ---- | ------------ |
| 0 | Playing | `new_game()` or transition complete |
| 1 | Game over | Score < 0, or timer reaches 0 |
| 2 | Title | Startup; any button on game over screen |
| 3 | Transitioning | Exit or teleport collected; 18-frame black/white flicker |

### SFX slots

| Slot | Event | Notes |
| ---- | ----- | ----- |
| 0 | Trap hit | C3→A2→G2→E2 descending, square wave, speed 10 |
| 1 | Treasure collected | C3→E3→G3→C4 ascending, square wave, speed 10 |
| 2 | Teleport activated | A2→C3→E3→G3→C4 ascending, noise, speed 6 |
| 3 | Exit reached | C3→E3→G3→C4→E4 ascending, square wave, speed 20 |

### State variables

```lua
-- constants (uppercase to avoid shadowing)
MW, MH    -- maze dimensions: 16×15
TS        -- tile size in pixels: 8

-- screen
gs        -- game state: 0=playing 1=game_over 2=title 3=transitioning

-- level
lseed     -- current level's RNG seed
lnum      -- levels completed; displayed as lnum+1

-- player
px, py    -- player map cell position
pdir      -- facing: 0=right 1=down 2=left 3=up
score     -- carries over between levels; game over if <0

-- timer
timer     -- countdown in seconds; game over at 0

-- screen flash
flash_t   -- remaining flash frames
flash_c   -- flash colour index

-- transition
next_seed -- seed for incoming level
next_tp   -- true: spawn at teleport tile; false: spawn at start
trans_t   -- transition countdown (18 frames)
```
