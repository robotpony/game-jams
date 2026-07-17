# 3 Falling — Design

**Superseded.** `3.p8` now exists; [CLAUDE.md](CLAUDE.md)'s Architecture section is the as-built source of truth, per [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md)'s document lifecycle. Kept here as historical pre-implementation reference (pixel layout, colour, state machine, tuning constants) — a few details below (paddle catch-flash, title stripe treatment) were never implemented; see CLAUDE.md's Known deviations.

## Screen layout (128×128)

```
y=0                                          
  |  playfield: items fall here
  |
  |
y=103   paddle travel row (8px tall, moves left/right, clamped to x=0..127)
y=111
y=112   HUD line (16px: lives | last-3-caught icons | score)
y=127
```

- Playfield: y=0–102, items spawn at y=0 and fall until they reach the paddle row or exit the bottom.
- Paddle row: y=103–110 (one 8px sprite row). The paddle never leaves this row; it only moves horizontally.
- HUD: y=111–127, two 8px text rows or one row with icon glyphs. Left-aligned lives, centered last-3-caught icons, right-aligned score (matches game 1's left/center/right HUD convention).

## Colour palette

Using Pico-8's native palette; the semantic item names map directly to Pico-8 colour names, so no approximation layer is needed for items:

| Element | Colour | Index |
| ------- | ------ | ----- |
| Grey item | light_gray | 6 |
| Blue item | blue | 12 |
| Red item | red | 8 |
| Orange item | orange | 9 |
| Green item | green | 11 |
| Item border (default) | white | 7 |
| Item border (grey item only) | black | 0 |
| Paddle fill | white | 7 |
| Paddle border | dark_blue | 1 |
| Background | black | 0 |
| HUD text | white | 7 |

Border rule: white border on all items for contrast against black, except grey items use a black border (white-on-light-grey reads poorly).

## Paddle

- Starts at 3 segments (24px), each rendered as an 8×8 block, and can grow via orange catches/combo up to a max of 5 segments (40px), centered under wherever it currently is.
- Segment count → width: 5 segments = 40px, 4 = 32px, 3 = 24px (start), 2 = 16px, 1 = 8px, 0 = 4px (a thin sliver; still wide enough to register a catch, but noticeably harder).
- Shrinks/grows symmetrically from center so the paddle's midpoint (used for input/collision) doesn't jump.
- Movement: left/right d-pad, clamped to screen bounds (`x = mid(4, x, 124)` adjusted for current width). Suggested speed: 2px/frame at 30fps.
- On red catch (segment loss), flash the paddle red for a few frames as a hit indicator. On orange catch (segment gain), flash white/green briefly.

## Items

- Spawn at a random x (aligned to keep the full sprite on-screen) at y=0.
- Colour chosen by weighted roll: grey 40, blue 25, red 15, orange 15, green 5 (out of 100).
- Fall speed starts at a base value and ramps linearly to 2× that value over the 90-second round (see Difficulty ramp below). All items on screen at a given moment share the current global fall speed.
- Spawn timer: a new item spawns every 1.2s (36 frames at 30fps), independent of how many items are already falling. Because fall speed increases over the round while spawn interval stays fixed, 2–3 items are typically on screen at once, more as the round progresses.
- Sprite: 8×8 bordered square (simplest "simple bordered shape" reading). Rectangle rather than circle/diamond keeps sprite budget and collision math simple.
- Collision (catch): item's bounding box overlaps the paddle's current bounding box at the paddle row → caught, remove item, apply catch effects (below).
- Miss: item's y exceeds the paddle row without having been caught → remove item, apply miss effect (lives -1).

## State machine

| `gs` | Name | Entered from | Exits to |
| ---- | ---- | ------------- | -------- |
| 0 | Title | startup | 1 (any button) |
| 1 | Playing | title, or "play again" from end screen | 2 (lives hit 0, or timer reaches 90s) |
| 2 | End | playing | 0 (any button) |

`won` (bool) is set when state 1 is exited via the timer rather than via lives reaching 0; the end screen branches its headline/sound on this flag.

## Resources & rules

**Lives**
- Start at 5, max 5.
- Any uncaught item of any colour (falls past the paddle) costs 1 life.
- Game over (loss) at 0 lives.

**Score**
- Per-catch deltas: grey +1, blue +2, green +4, red -2, orange +1.
- Floored at 0 for display (never shown negative), though this only matters in practice if a red catch happens before any points are banked.

**Paddle segments**
- Start at 3, max 5, min 0.
- Red catch: -1 segment. Orange catch: +1 segment (no-op if already at 5, but orange's +1 score and +1 life still apply), +1 life (capped at 5).
- Independent of lives; reaching 0 segments does not end the game by itself.

## Combo system

- Track the colours of the last 3 successful catches in a small ring buffer (any colour counts, including red/orange).
- When all 3 entries match, trigger that colour's combo, then clear the buffer (next combo requires a fresh streak of 3).
- Combo effects:

| Colour | Effect |
| ------ | ------ |
| Blue | +10 score |
| Green | +1 life (capped at 5) |
| Orange | Lives reset to 5, +1 paddle segment (capped at 5) |
| Red | +25 score |
| Grey | +5 score |

- On trigger: fill the screen with the combo colour, overlay "COMBO" text in a contrasting colour (white on dark fills, black on light/grey fills), hold 500ms (15 frames at 30fps), then resume normal rendering.

## Difficulty ramp & win condition

- Round length: 90 seconds (2700 frames at 30fps).
- Fall speed: `spd = base_spd + (base_spd * (t / 2700))`, linearly interpolated so speed is `base_spd` at t=0 and `2 * base_spd` at t=2700.
- Win: timer reaches 2700 frames while lives > 0 → `gs = 2`, `won = true`.
- Loss: lives reach 0 at any point → `gs = 2`, `won = false`, regardless of timer.

## Screens

**Title** — Intellivision-style: black background, a bordered colour-band frame (alternating stripes in the item palette: grey/blue/red/orange/green), large blocky "3 FALLING" centered, blinking "PRESS 🅾️ TO START" prompt beneath.

**Game** — Playfield + paddle + HUD as laid out above. No pause state.

**End** (shared layout, win/loss differ only in headline text and sound) — Centered headline ("GAME OVER" or "YOU SURVIVED"), then final score, items caught, and items missed, stacked below. Any button returns to title.

## Sound

| Event | Description |
| ----- | ------------ |
| Grey catch | Bing, note C |
| Blue catch | Bing, note D |
| Red catch | Pink-noise explosion (not melodic) |
| Orange catch | Bing, note F |
| Green catch | Bing, note G |
| Combo (any colour) | Chord starting on that colour's note |
| Loss | 3 descending melodic notes |
| Win | 3 ascending melodic notes |

Note assignment follows the catch-effect ordering in the README (C, D, [red is noise], F, G) — red keeps the explosion instead of a bing since it's a negative event, so it skips the melodic slot rather than reusing E.

## Token budget

This design carries more state than game 1: two health pools (lives, paddle segments), a weighted spawn table, a 3-slot combo buffer, and a time-based difficulty ramp. Lean on [`lib/`](../lib/CLAUDE.md) for shared primitives (input, screen flash, state machine, seeded RNG) rather than re-deriving them, and keep the combo/spawn tables as flat arrays indexed by colour id rather than branching per-colour code.
