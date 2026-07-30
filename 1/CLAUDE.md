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

**Map layout** — Tile type IDs stored in the `maze` table (not Pico-8 map tiles). Tile IDs: 0=floor, 1=wall, 2=start, 3=exit, 4=trap, 5=treasure, 6=teleport, 7=ammo. Player is drawn with primitives, not stored in the maze.

**Collision** — `mg(x,y)` reads a tile (returns 1 for out-of-bounds). Check before moving; wall tiles block, item tiles trigger `handle_tile()` then become floor.

**Monsters** — `mons` is an array of `{path,idx,dir,x,y,t,dead,rt}`. Spawned in `gen_level()` on dead-end cells chosen from an independent copy of `e` (`em`), shuffled separately from the copy items are placed from; count is `min(1+rnd(3), #em)`, so a level normally has 1-3. This maze's `carve()` (step-2 grid, classic recursive backtracker) produces long winding corridors with surprisingly few dead ends — a 3000-seed simulation found a median of 6 per level, sometimes as low as 1 — so monster count originally shared the same leftover-dead-end pool as items (up to 9 possible item slots) and came up 0 on roughly half of levels. Drawing monsters from their own shuffle instead of the leftover tail fixes that; the tradeoff is a monster can occasionally land on the same cell as an item, which is harmless since monsters don't consume or block tiles. `build_path(x,y)` walks from a dead-end cell along the corridor (`opens(x,y)` gives the single starting direction; at each subsequent cell, `opens()` again and continue in whichever of its 2 open directions isn't the one just arrived from) for up to 8 cells, or until it hits a junction (`#opens()~=2`) or another dead end. `upd_mons()` advances `idx` by `dir` one cell every `8+rnd(10)` frames (randomized so the patrol isn't a fixed, learnable period), reversing `dir` at either end of `path` — a hard per-cell jump, not tweened, matching the player's own per-cell movement. Monsters are deliberately non-blocking — the maze from `carve()` is a perfect maze (recursive backtracking, one path, no loops), so a solid obstacle could permanently wall off the exit; contact is a triggered effect instead (`check_hit()`, resets `px,py` to `1,1`, always the start tile since `ms(1,1,2)` runs after `carve()` and is excluded from `dead_ends()`).

**Shooting** — `shot` is `nil` or `{x,y,dx,dy}` in pixel space (one shot in flight at a time), fired on `btnp(5)` if `ammo>0` and `shot_cd<=0`. `upd_shot()` advances it 4px/frame along the facing direction (`pdir` at fire time), resolving each frame via `mg(flr(shot.x/TS), flr(shot.y/TS))`: a wall tile clears the shot, a live monster's cell sets `m.dead=true` and `m.rt=90` (3s respawn) and clears the shot. `respawn_mon()` re-picks a dead-end cell via a fresh `dead_ends()`/`shuf()` call (cheap; only runs on the rare kill event) and resets the monster's patrol points from it.

**HUD** — Bottom strip (y=120–127): score left, level number centered, ammo (`"a"..ammo`) right of centre, timer right. Drawn every frame over the game area.

**Screen flash** — On item pickup, set `flash_t` (frames) and `flash_c` (colour). In `_draw()` during playing state, if `flash_t > 0`, fill the game area with `flash_c` instead of drawing the maze, then decrement.

**Title screen** — Uses the shared jam title card from [`../lib/title.lua`](../lib/title.lua) and [`../lib/screen.lua`](../lib/screen.lua) (`draw_title_card`, `blink`), pasted into this cart's `__lua__` section. `gs==2` calls `draw_title_card("#1")`; no per-game title-drawing code remains.

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
| 4 | Shot fired | Two-note descending blip, square wave, speed 3 |

Monster contact reuses slot 0 (same "hit" character as a trap); ammo pickup and defeating a monster both reuse slot 1 (same "reward" character as treasure). Deliberate reuse to avoid hand-authoring more tracker data than the new actions strictly need.

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

-- monsters (mons: array of these) and shooting
mons      -- {path, idx, dir, x,y, t, dead, rt} per monster; path is a list of cells from build_path(), idx/dir step through it, x/y mirror path[idx]
ammo      -- shot count; starts at 10, +1 per kill, +2 per ammo pickup; carries over between levels like score
shot      -- nil, or {x,y,dx,dy} in pixel space; at most one shot in flight
shot_cd   -- frames until the next shot can be fired
```

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for shared Lua snippets before writing new utility code from scratch. This cart pastes in `blink()` (`lib/screen.lua`) and `draw_title_card()` (`lib/title.lua`) for its title screen; everything else here predates extraction and remains bespoke.

### Known bugs

Tracked in [`../BUGS.md`](../BUGS.md#1--maze-game) (entries 1.1–1.3): teleport increments the level counter by the seed offset instead of by 1, the exit tile isn't guaranteed a slot when placing items onto dead ends, and the timer resets on teleport though README only documents that for Exit and Treasure.
