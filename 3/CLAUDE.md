# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "3 Falling" — an action/puzzle item-catching game with Atari 2600 aesthetics, built for the "Warped 2026 Game Jam 1". The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: built.** `3.p8` exists and implements all 7 phases of [PLAN.md](PLAN.md). The Architecture section below documents the as-built cart, read directly from `3.p8`; per [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md), it supersedes [DESIGN.md](DESIGN.md) as the source of truth for how the game actually works.

## Development

Pico-8 has no build system, package manager, linter, or test runner. The workflow is:

- Edit the `.p8` file in an external editor or inside Pico-8's built-in editor
- Run with `pico8 -run 3.p8` (requires Pico-8 installed)
- Or open Pico-8, then `load 3.p8` and press Ctrl+R to run

Verification is manual: load the cart and play it.

## Pico-8 Constraints

These constraints shape every implementation decision:

- **Token limit**: ~8,192 tokens total; code is compressed and must be counted aggressively
- **Display**: 128×128 pixels, 16-colour palette
- **Sprites**: 8×8 pixels each, 256 slots in the sprite sheet
- **Map**: 128×64 cells, shared memory with the bottom half of the sprite sheet
- **Sound**: 64 SFX slots, 4 channels
- **Lua variant**: Pico-8 Lua omits parts of the standard library; no `string.format`, use `tostr()`, `tonum()`, `sub()`, `#str`, `add()` for tables

## Architecture

The game follows the standard Pico-8 callback structure in a single `3.p8` file:

```lua
_init()   -- called once on startup: set base speed/paddle speed, gs=0 (title)
_update() -- called 30fps: title/end input, timer, paddle movement, item spawn/fall/catch, combo checks
_draw()   -- called 30fps: dispatches to draw_title / draw_end / combo flash / gameplay draw
```

### Key systems

**Item colour table** — `colc={6,12,8,9,11}` (grey, blue, red, orange, green Pico-8 colour indices), `colsc={1,2,-2,1,4}` (score deltas), `catch_sfx={0,1,4,2,3}`, `combo_sfx={5,6,7,8,9}`. Colour id `it.c` (1–5) indexes all four in parallel; this is the flat-array-by-colour-id approach DESIGN.md's Token budget section called for instead of per-colour branching.

**Spawn/fall** — `rnd_col()` weighted roll (40/25/15/15/5) picks a colour; a new item is added to `itms` every 36 frames (`spawn_t`, 1.2s at 30fps) at `x=rnd(121), y=0`. Each item falls at the shared global `spd`, recomputed every frame.

**Difficulty ramp** — `spd = base_spd + base_spd * (t/2700)`, `base_spd=1`, `t` the frame counter capped at 2700 (90s at 30fps). Win fires at `t>=2700` if the round hasn't already ended in a loss.

**Catch/miss** — per item, a bounding-box check (`it.y+7>=py and it.y<=py+7` and `it.x` overlap with the paddle) determines a catch; falling past `py+7` uncaught is a miss (`lives-=1`, game over at 0). Caught items apply `colsc` to score, adjust `pseg` for red/orange, and feed the combo tracker.

**Paddle** — `pseg` (0–5, starts 3) drives `paddle_w()`: `pseg*8` px, or a 4px sliver at 0. `pmid` (centre x) is clamped to `[pw/2, 128-pw/2]` and moves at `pspd=3` px/frame on left/right input; `px = pmid - pw/2` is recomputed every frame before drawing.

**Combo tracking** — `last3` holds up to 3 recent catch colours (`deli` trims to a sliding window). When all 3 match, `trigger_combo(c)` applies the colour's score/lives/segment effect, sets `flash_t=15` (500ms) and `flash_c`, and clears `last3` so a fresh streak of 3 is required again.

**Screen flash** — `flash_t>0` freezes gameplay (no spawn/fall/timer advance) and fills the screen with `flash_c` plus a "combo" text overlay in `_draw()`; used only for the combo trigger, not for individual catches (see Known deviations below).

**HUD** — drawn every frame at y=113+ over the playfield: lives left, last-3-caught colour swatches centred, score right (floored at 0 via `max(0,score)`).

**Title screen** — Uses the shared jam title card from [`../lib/title.lua`](../lib/title.lua) and [`../lib/screen.lua`](../lib/screen.lua) (`draw_title_card`, `blink`), pasted into this cart's `__lua__` section. `gs==0` calls `draw_title_card("3 FALLING")` directly in `_draw()`; the old per-game `draw_title()` function is gone. `draw_end()`'s "press any button" prompt also now uses `blink(2)` instead of a hand-rolled counter.

### Game states

| `gs` | Name | Triggered by |
| ---- | ---- | ------------ |
| 0 | Title | Startup; any button from End |
| 1 | Playing | `new_game()`, called on any button from Title |
| 2 | End | Lives reach 0 (`won=false`), or `t` reaches 2700 (`won=true`) |

### SFX slots

| Slot | Event | Notes |
| ---- | ----- | ----- |
| 0 | Grey catch | Single note C (pitch 0x24), square-ish tone, speed 8 |
| 1 | Blue catch | Single note D (0x26), speed 8 |
| 2 | Orange catch | Single note F (0x29), speed 8 |
| 3 | Green catch | Single note G (0x2b), speed 8 |
| 4 | Red catch | Noise waveform, low pitch (0x14), fade-out effect, speed 6 — the "pink-noise explosion" |
| 5 | Grey combo | C major triad (C-E-G), speed 3 |
| 6 | Blue combo | D major triad (D-F#-A), speed 3 |
| 7 | Red combo | E major triad (E-G#-B) — uses the E slot the single-catch scheme skips, since red isn't melodic solo | 
| 8 | Orange combo | F major triad (F-A-C), speed 3 |
| 9 | Green combo | G major triad (G-B-D), speed 3 |
| 10 | Loss | G-E-C, 3 descending notes, speed 12 |
| 11 | Win | C-E-G, 3 ascending notes, speed 10 |

### State variables

```lua
-- lookup tables, indexed by colour id 1-5 (grey, blue, red, orange, green)
colc, colsc, catch_sfx, combo_sfx

-- screen
gs        -- game state: 0=title 1=playing 2=end
t         -- frame counter, 0-2700 (90s at 30fps)

-- difficulty
spd, base_spd, pspd  -- current/base fall speed, paddle move speed

-- paddle
px, py    -- paddle top-left; py fixed at 103
pw, pmid  -- current width (from pseg), centre x
pseg      -- segments: 0-5, starts 3

-- items
itms      -- array of {x, y, c}; c is colour id 1-5
spawn_t   -- frames until next spawn, resets to 36

-- resources
lives     -- 0-5, starts 5; game over at 0
score     -- can go negative internally; displayed floored at 0
won       -- set true only when state 1 exits via t>=2700

-- combo
last3     -- sliding window of up to 3 recent catch colours

-- screen flash (combo only)
flash_t, flash_c

-- end-screen stats
caught_ct, missed_ct
```

### Known deviations from DESIGN.md

Tracked in [`../BUGS.md`](../BUGS.md#3--falling) (entries 3.1–3.3): no per-catch paddle flash, title/combo/end-screen text printed lowercase instead of the spec's quoted uppercase, and an ambiguous read of "alternating stripes" on the title frame.

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for shared Lua snippets (input handling, screen flash/fade, state machine, tweening, collision, HUD, map queries, seeded RNG) before writing new utility code from scratch. Snippets are copy-pasted into this cart's `__lua__` section, not imported — inline only what's needed given the shared token budget.
