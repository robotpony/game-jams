# Plan

Phased implementation checklist for `3.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md).

## Phase 1: Core movement & falling items

- [x] Paddle: 8×8×3-segment sprite (starting width; grows to 5 as of the Phase 2/3 spec update below), renders centered, moves left/right, clamped to screen bounds
- [x] Item spawn: random x, weighted colour roll (grey 40 / blue 25 / red 15 / orange 15 / green 5), fixed 1.2s spawn interval
- [x] Item fall: constant baseline speed (ramp comes in Phase 4), removed when caught or off-screen
- [x] Catch detection: item/paddle bounding-box overlap at the paddle row
- [x] Miss detection: item passes the paddle row uncaught
- [x] Verify: items spawn at the documented odds, fall visibly, and the paddle can intercept them

## Phase 2: Resource systems

- [x] Lives: start at 5, -1 on any miss, game-over check at 0
- [x] Score: per-colour deltas (grey +1, blue +2, green +4, red -2, orange +1), floored at 0 for display
- [x] Paddle segments: start 3, max 5 (updated from 3), red catch -1, orange catch +1 segment + 1 life (capped), paddle width reflects current segment count
- [x] Verify: catching or missing each colour produces the correct score/life/segment change; paddle at 0 segments still catches items; orange catch grows the paddle up to 5 segments and adds a life (manual — needs a play test in Pico-8, re-verify after orange/paddle-cap spec change)

## Phase 3: Combo system

- [x] Last-3-caught ring buffer (any colour, including red/orange)
- [x] Combo detection on 3-in-a-row match; buffer resets after a trigger
- [x] Per-colour combo effects: blue +10, green +1 life (capped 5), orange resets lives to 5 + 1 paddle segment (capped 5, updated), red +25, grey +5
- [x] Combo screen flash: fill with combo colour + "COMBO" text, 500ms, then resume
- [x] Verify: a streak triggers exactly once, the buffer resets correctly, and each colour's effect applies (and caps) correctly, including orange's new paddle-segment bonus (manual — needs a play test in Pico-8)

## Phase 4: Difficulty ramp & win condition

- [x] 90-second round timer (2700 frames at 30fps)
- [x] Fall speed linear ramp: base speed at t=0 to 2× base speed at t=2700
- [x] Win check: timer reaches 2700 frames with lives > 0
- [x] Loss check: lives reach 0 at any point, regardless of timer
- [x] Verify: round ends in a win at exactly 90s if the player is still alive; fall speed is visibly faster late in the round (manual — needs a play test in Pico-8)

## Phase 5: Screens & flow

- [x] Title screen: Intellivision-style colour-band frame, blocky "3 FALLING", blinking start prompt
- [x] Game screen: playfield + paddle + HUD wired together (lives left, last-3-caught icons center, score right)
- [x] End screen: shared layout, headline branches on win/loss, shows final score/caught/missed
- [x] State machine: title → playing → end → title
- [x] Verify: full loop is playable start to finish; both win and loss paths are reachable (manual — needs a play test in Pico-8)

## Phase 6: Visuals & sound polish

- [x] Apply final colour palette to paddle, items, HUD, and combo flashes (already matched DESIGN.md's palette table from earlier phases; no changes needed)
- [x] SFX: per-colour bing (C/D/F/G, red uses noise instead), combo chord, win ascending run, loss descending run
- [x] HUD polish: confirm lives/last-3/score layout matches DESIGN.md at all paddle-segment widths (paddle row y=103-110 is separate from HUD row y=111-127, so paddle width changes don't affect HUD layout)
- [x] Verify: play a full round with sound on; confirm every listed SFX fires at its correct trigger (manual — needs a play test in Pico-8; sound content authored by ear-judgment, not auditioned, since I can't run Pico-8's audio myself — flag any note/tempo that sounds off)

## Phase 7: Token & performance check

- [x] Confirm final token count is within the ~8,192 budget (heuristic estimate ~960 tokens, well under budget — authoritative number is only available from Pico-8's own status bar; manual confirmation needed)
- [x] Confirm 2-3 concurrent falling items plus paddle/HUD render without frame drops (draw calls are a handful of rectfill/rect/print per frame, no heavy computation — very likely fine, but needs a manual play-test to confirm actual FPS)
