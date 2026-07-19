# 3 FALLING

This is a action/puzzle game built using Claude and Pico-8. Follows the format in [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

The game looks like an Atari 2600 game. Colours, sprites, and fonts should approximate the Atari 2600 aesthetic using Pico-8's palette.

## Game overview

- items fall from the top, down to the bottom of the screen and out of view, unless a player catches them with the paddle
- item colours, catch effects, and spawn odds:

  | Colour | Spawn odds | Score on catch | Other effect on catch |
  | ------ | ---------- | --------------- | ---------------------- |
  | Grey   | 40% | +1 | none |
  | Blue   | 25% | +2 | none |
  | Red    | 15% | -2 | paddle -1 segment |
  | Orange | 15% | +1 | paddle +1 segment (capped at 5), lives +1 (capped at 5) |
  | Green  | 5%  | +4 | none |

- letting any item (any colour) fall past the paddle uncaught is a miss: lives -1
- lives start at 5; game over when lives reach 0
- the paddle has its own health, separate from lives: starts at 3 segments, min 0, capped at 5
  - catching red removes 1 segment (min 0); at 0 segments the paddle is at its minimum width but still catches items and the game continues, gated only by lives
  - catching orange restores 1 segment (max 5) and adds 1 life (max 5)
- the round is won by surviving 90 seconds without running out of lives
  - items fall at a constant spawn rate: one new item every 1.2 seconds, with up to 2-3 items falling concurrently
  - fall speed ramps linearly over the 90 seconds, reaching roughly 2x the starting speed by the end
- players control a paddle that moves left and right at the bottom of the screen
- the HUD (bottom line) shows the remaining lives count and score, and the middle section showing the last 3 pieces caught by the player
- if the last 3 pieces caught match (same colour), a combo is triggered; the tracker then resets, so a fresh streak of 3 is needed to combo again
  - a blue combo adds 10 to the score
  - a green combo adds back one life (capped at 5)
  - an orange combo resets a player's lives to 5 and adds 1 paddle segment (capped at 5)
  - a red combo adds 25 points
  - a grey combo adds 5 points
  - when a combo shows, the screen flashes to the colour with "COMBO", then back to the game (500ms)

## Scenes

| Scene | Shows | Enters from | Exits to |
| ----- | ----- | ------------ | -------- |
| Title | Shared jam title card: colour-swatch strip, "'26 WARPED GAME JAM", "3 FALLING", blinking start prompt | Startup | Any button → Game |
| Game | Playfield (items fall from the top), player paddle, HUD | Title, or "play again" from End | Lives hit 0, or timer reaches 90s → End |
| Combo flash | Screen fills with the combo colour, "COMBO" text overlay | 3 matching catches in a row | 500ms (15 frames) → resumes Game |
| End | Shared win/loss layout: headline ("GAME OVER" on loss, "YOU SURVIVED" on win), final score, items caught, items missed | Game | Any button → Title |

## Sprites

- the paddle is a horizontal bordered bar; its width/appearance reflects current segment health (0 through 5 segments)
- items are simple bordered shapes: fill colour carries the semantic colour (grey/blue/red/orange/green), border is a simple contrasting outline (black or white) for readability, not a literal colour-wheel complement

## Sounds

- simple explosion sound (pink noise) when a red item hits the player's paddle
- a "bing" sound when other items hit it, one per colour. bings should be melodic (C, D, E, F, G)
- when a combo is completed, it plays a chord, using the notes starting with the colour's note
- when a player loses (lives reach 0), 3 descending melodic notes play
- when a player wins (survives the full 90 seconds), 3 ascending melodic notes play
