# Plan

Phased implementation checklist for `4.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md). Nothing is built yet; all phases are pending. Design is locked, no phase below is blocked on an open question.

## Phase 1: Ship arc movement & radial shooting

- [x] Ship position represented as an angle `sang`, clamped to ±69° (a 21° trim off the true ±90° endpoints, keeping the 8×8 sprite fully on-screen; derivation in DESIGN.md)
- [x] Left/right input adjusts `sang` at `sturn = 2°/frame` (default, tune once playable) within that clamp
- [x] Shared `arc_xy(cx, cy, r, a)` helper added to `lib/math.lua` before wiring ship position; 3 enemy arcs and both shot types reuse the same math, so deriving it once here pays off immediately. Implementing it surfaced a gotcha not visible from the DESIGN.md formula alone: Pico-8's built-in `sin()` is inverted from standard math convention (`sin(x) == -sin(2*pi*x)`, a consequence of its y-down screen coordinates), so the helper negates the sin term to keep "increasing angle" sweep rightward, matching the left/right button mapping.
- [x] Hold-to-fire: spawns a shot every 4 frames while held, travelling 4px/frame along the radius vector through `sang` at the moment of firing
- [ ] Verify (manual play test, not yet done): ship visibly sweeps along a curve rather than a straight line, clamps cleanly at both ends without the sprite clipping off-screen; a shot fired from each end of the arc travels in a visibly different direction; holding fire produces a steady stream of shots

Implemented in `4.p8` with placeholder visuals only (filled circle for the ship, single pixels for shots); real sprites land in Phase 7.

**Follow-up fix**: the arc's orientation in the original spec was backwards (a dome opening downward, centre below the screen) instead of a valley opening upward toward the screen edges (centre above the screen), per a corrected spec — see DESIGN.md's Arc geometry note. `CX,CY` moved from `(64,103)` to `(64,25)`, `arc_xy()` in `lib/math.lua` now adds the cos term instead of subtracting it, and the player's shot direction flipped from outward to inward (`arc_xy(0,0,-1,sang)`). The four checked items above are still correct in shape, but `4.p8`'s constants and shot-direction call were updated to match; re-verify after this fix, not just the original implementation.

## Phase 2: Enemy arcs & formation

- [x] Three enemy arcs at radii 53/43/33 (centred position y=108/98/88, band-edge/topmost y≈89/88/84), angular bands ±50°/±40°/±30°
- [x] Wave 1 starting counts: 7/6/5 (18 total), evenly spaced within each arc's band
- [x] Enemies sweep back and forth within their arc's band
- [x] Shot/enemy collision detection (player shot vs enemy)
- [x] Enemy entrance, phase 3 (grow into formation): each enemy reaches `r=0` at the shared centre and spirals out to its tier's radius while sweeping, rather than appearing pre-placed on its band (added after first play test — see DESIGN.md's Enemy entrance note)
- [x] Enemy entrance, phase 1 (circle at entry point): each enemy orbits a second fixed point near the top of the screen `(64,12)` at a small radius, spread by starting angle offset so they don't stack
- [x] Enemy entrance, phase 2 (spiral to shared centre): each enemy's position blends from its orbit formula toward the shared centre over the phase's duration, reading as a decaying spiral rather than a straight glide
- [x] Vanishing-point dot and spoke lines drawn at the shared centre, entry-point dot drawn at the second point, pulled forward from Phase 7's visual polish since the enemy entrance depends on both points reading as deliberate spots rather than empty space
- [x] Placeholder animated background grid (12 horizontal lines, spacing 24px→8px) tied to entrance progress, standing in for Phase 7's real background grid until the two are reconciled
- [x] Enemies scale in size with distance from the shared centre (small far away near the entry point, growing to full size as they spiral in), and formation sweep slows to half speed once fully settled into the radial/formation phase (added after a fourth play test)
- [x] Radial spoke lines extended to reach the screen edge (previously stopped at the ship's own arc radius, which read as too short)
- [x] Background grid switched from a time-animated squeeze to a static spacing gradient centred on the shared centre's y-coordinate, so distance is shown spatially rather than by an unmotivated animation
- [ ] Verify (manual play test, not yet done): enemies visibly enter from a point near the top of the screen, circle for several revolutions, then spiral down — visibly growing larger as they approach the shared centre — into three distinct curved bands above the ship that sweep slowly; the background grid is static and denser near the shared centre than at the screen edges; the spoke lines reach the screen edge; a player shot that crosses an enemy's position destroys it at any point in the entrance

Implemented in `4.p8` with placeholder visuals (`circfill` dots for enemies, colour 8, radius scaled by distance from the shared centre rather than fixed; sky-blue dot and dark-blue spoke lines for the shared-centre vanishing point; yellow dot for the entry point; dark-blue lines, matching the spoke-line colour, for the static background grid); real sprites land in Phase 7. Each enemy sweeps independently back and forth within its own tier's band (own `dir` flipping at `ea=±B`), rather than the whole tier moving as a single rigid block; since all enemies in a tier share the same speed but start at different evenly-spaced offsets, they naturally reach their band edges and reverse at different frames, giving a staggered rather than lockstep sweep. Collision is a flat `abs(dx)<3 and abs(dy)<3` box check between each in-flight shot and each enemy, run as a reverse double loop over `shots`/`en` so deletions mid-loop are safe; it runs unconditionally, so enemies can be shot down during any entrance phase, not just once settled into formation. The hitbox stays a fixed 3px box regardless of the enemy's draw-only size, so it isn't harder to hit up close than far away.

**Follow-up (third pacing/visual pass)**: `ND1`/`ND2` doubled to 360 frames each (12s per phase, ~24s for phases 1+2 combined) and `CSPD` doubled to 0.01, giving roughly 3.6 revolutions around the entry point during phase 1 alone versus under 1 before — a much more visible circling motion before the spiral-in begins. Enemy dots shrank from a 2px `circfill` to a single-pixel `pset` (collision hitbox unchanged). The animated background grid switched from orange (9) to the same dark blue (1) as the radial spoke lines, so the two line systems read as one visual family instead of two competing colours.

**Follow-up (fourth pass)**: enemies now draw at `mid(1, (60-dist)/10, 3)` radius, `dist` their live distance from the shared centre, recomputed every frame regardless of entrance phase — this both answers "make them bigger as they approach" and, as a side effect, reproduces the eventual Phase 7 "outer tier reads bigger" sprite rule for free once settled into formation, since the outer tier sits closest to the shared centre. `ESPD` (formation sweep speed) halved to `0.0007`; because `ea` only drives visible position in the settled/radial phase (phases 1-2 use the orbit/spiral formulas instead), this only slows movement once an enemy has arrived, not the entrance itself. The radial spoke lines' reach grew from the ship's own arc radius (64px) to a deliberately oversized 200px, letting Pico-8's automatic line-clipping stop them exactly at the screen edge instead of short of it. The background grid dropped its `ET`-driven animation entirely in favour of a static gradient of line pairs straddling the shared centre's y-coordinate (tight near the centre, spreading toward the edges) — a play-test note flagged the animated version as unmotivated movement rather than a legible distance cue.

**Follow-up (first play test)**: the initial version placed enemies pre-formed on their bands (y=84-108), which read as using only the screen's lower half with the top left empty. Moving the shared centre `(64,55)` up wasn't viable without changing the ship's arc radius (see CLAUDE.md's discussion of why `cy+64` is fixed to the ship's rest position). The first fix made enemies spawn at the shared centre (`r=0`) and grow outward while sweeping.

**Follow-up (second play test)**: extended to a full two-phase entrance: enemies now start by circling a second, independent point near the top of the screen, then spiral from there to the shared centre before the original grow-into-formation behaviour takes over, driven by one global frame counter `ET` (`ND1=180`, `ND2=180` frames, ~12s total before the formation phase's own ~1.8s tail). A single animated background grid whose row spacing tightens over the same timeline was added to reinforce the "closing in" pacing. Re-verify against this version.

## Phase 3: Enemy attack behaviour

- [x] Each enemy independently fires a shot outward along its radius vector (`arc_xy(0,0,1,ea)`, away from the centre and therefore down toward the ship — enemies sit at smaller radii than the ship, so "outward" is toward the ship here, the opposite of the player's own inward shots) on a wave-scaled cooldown (`max(20, 90-5*(w-1))` frames); gated on `e.r>=ER[e.tr]` so an enemy only starts firing once its entrance (Phase 2) has fully settled it into formation
- [x] Each enemy independently has a wave-scaled per-second chance to break formation and dive toward the ship's last-known position (`min(0.5, 0.05+0.015*(w-1))`, converted to a per-frame roll as `dch/30`), at `base_dvspd = 3px/frame` scaled the same way as formation speed (default, tune once playable)
- [x] Dive miss handling: an enemy that goes off-screen without hitting the ship does **not** leave the wave; it respawns at the *outer edge of its angular band* (`ea=±B` for its tier, the highest point it can reach, not `ea=0` which is its centred/lowest position) and resumes formation sweep, with a per-enemy miss counter (`e.mc`) that makes its next dive faster and its own fire cooldown shorter each time (both capped after ~7 misses). A wave must always clear via kills, never via unshot enemies dodging their way out of the roster.
- [x] Player-hit collision (enemy shot or diving enemy vs ship) reduces lives (`lv`, starts at 5 per README.md's Resources line); a diving enemy that hits the ship resolves as a hit and immediately returns to formation at its band edge (same respawn path as a miss, but without incrementing the miss counter)
- [x] Entity cap enforced: total enemies + enemy shots never exceeds 32 (a respawning diver doesn't hold a slot during its brief off-screen instant); a fire event that would exceed it is skipped for that frame rather than queued (diving itself never needs the check, since a diving enemy doesn't create a new entity — see DESIGN.md's Entity cap note)
- [ ] Verify (manual play test, not yet done): enemies visibly fire back and occasionally dive; a missed dive re-enters at the top and is visibly more aggressive on its next attempt; getting hit reduces lives (shown as a placeholder `lv N` readout, top-left); entity count never visibly exceeds the cap even with fire and dive both active

Implemented in `4.p8` with placeholder visuals (pink `pset` for enemy shots, distinct from the player's white shots; `lv N` text top-left standing in for Phase 6's real HUD). Enemy state gained `dv` (diving flag), `dvx`/`dvy` (dive velocity), `dvsg` (which band edge to respawn at, captured from `sign(ea)` at dive start), `mc` (miss count), and `fc` (fire cooldown, staggered at spawn via `rnd(90)` so the first volley isn't synchronized). The enemy update loop now branches on `e.dv`: diving enemies move in a straight line and check only for a ship hit or going off-screen, while formation enemies keep the existing entrance/sweep logic and, once settled, roll for fire and dive independently each frame. Ship position (`shx,shy`) is computed once per frame at the top of `_update()` and reused for the player's own shot spawn, dive targeting, and both hit-collision checks, rather than recomputed per use. Wave-scaled formulas (`wfc` fire cooldown, `dch` dive chance, and the dive-speed wave multiplier) all reference a `wv` variable fixed at 1 for now; Phase 4 will update `wv` as waves progress and these formulas already feed off it correctly.

## Phase 4: Waves & progression

- [x] Wave clears when its enemy count reaches 0
- [x] Next-wave enemy count `min(24, 18+2*(w-1))`, formation speed `base_espd*(1+0.08*(w-1))` (`base_espd = 0.5°/frame` default), feeding Phase 2/3's placement and behaviour formulas
- [x] Lives (5 start), score tracking: `50*arc_tier + (50 if diving when destroyed)` per kill
- [ ] Verify (manual play test, not yet done): clearing every enemy on a wave triggers the next wave with a visibly larger/faster formation; losing all 5 lives ends the round; score increases correctly by arc tier and dive bonus

Implemented in `4.p8` with a placeholder HUD readout (`lv N sc N w N`, top-left) standing in for Phase 6's real HUD; there's no `gs` state machine yet, so wave transition and game over are placeholder behaviours pending Phase 6's real screens, decided during review rather than left to guesswork:

- **`base_espd`**: DESIGN.md's literal `0.5°/frame` (0.00139 turns/frame) predates Phase 2's fourth-pass tuning, which had already halved the live `ESPD` constant to `0.0007` for feel reasons. `base_espd` is the tuned `0.0007`, not the original spec number, so wave 1's formation speed matches what's already been played; the wave-scaling formula applies on top of it (`local espd=ESPD*(1+0.08*(wv-1))`, computed once per frame and used in place of the bare `ESPD` constant).
- **Wave clear**: detected at the end of `_update()` (`#en==0`), which sets a 36-frame freeze counter (`frz`) rather than transitioning immediately. During the freeze, `_update()` returns early after decrementing `frz` (skipping ship movement, shot movement, and all enemy logic), so the playfield reads as frozen rather than continuing to animate with no enemies on screen — a placeholder for Phase 6's real wave-transition overlay, which will show "WAVE n" text over this same frozen frame instead of nothing.
- **Wave re-entrance**: once the freeze ends, the next wave replays the *full* two-phase entrance (`ET=0`, `en`/`eshots` cleared, `spawn_wave()` called again) rather than spawning enemies directly into formation. This reuses Phase 2's entrance code unchanged at the cost of the same ~25.8s entrance repeating every wave; revisit if playtesting finds that too slow a cadence between waves.
- **Tier split**: the enemy-count formula only specifies a wave total, not a per-tier split. A new `spawn_wave()` function (replacing the old fixed `EN={7,6,5}` table and its dedicated spawn loop in `_init()`, both removed) computes each tier's count by scaling the wave-1 7:6:5 ratio (`t1=flr(n*7/18+0.5)`, `t2=flr(n*6/18+0.5)`, `t3=n-t1-t2`), keeping the same inner-heaviest silhouette at every wave size (18→24) instead of skewing toward one tier as the count grows. `_init()` now just resets state and calls `spawn_wave()`, so wave 1's spawn and every later wave's respawn share one code path.
- **Game over**: `lv<=0` sets an `over` flag; `_update()` returns immediately at the top when `over==1`, freezing the game permanently (no auto-restart) since Phase 6 hasn't added an End screen to transition to yet. `over` is checked before `frz`, so a lives-out and wave-clear on the same frame resolves as game over, not a wave transition.
- **Score**: added at the point of a shot/enemy collision (`sc+=50*e.tr+(e.dv==1 and 50 or 0)`), since that's the one place both the killed enemy's tier and its diving state are already in scope; a diving enemy that's shot rather than one that hits the ship is what triggers the dive bonus, matching DESIGN.md's "destroyed while diving," not "was diving at some point."

## Phase 5: Token checkpoint (core systems)

- [x] Count tokens with Phases 1-4 implemented: ship movement, enemy arcs/formation, attack behaviour (fire, dive, miss-respawn), waves/progression, entity cap
- [x] Compare against a soft ceiling of ~4,000 tokens for core systems (roughly half the ~8,192 total), leaving room for Phase 6's screens/HUD and Phase 7's sprites/SFX
- [x] If over the soft ceiling, simplify before continuing (e.g. cut the miss-intensity stacking, simplify dive-vs-formation state, or move more shared math into `lib/`) rather than discovering the problem after art and sound are already built
- [x] Verify: token count recorded; explicit decision made (proceed, or simplify first) before starting Phase 6

Measured via `p8tool stats 4.p8` (picotool): **1,415 tokens**, 220 lines, 4,567 chars. Well under the ~4,000 soft ceiling (about a third of it), so no simplification pass is needed; proceeding straight to Phase 6 with all of Phases 1-4's logic intact.

## Phase 6: Screens & flow

- [ ] Title screen: call the shared `draw_title_card("GYRI #4")` from [`../lib/title.lua`](../lib/title.lua); paste `blink()` (`lib/screen.lua`) and `draw_title_card()` into `4.p8`'s `__lua__` section rather than hand-rolling
- [ ] Wave-transition overlay: "WAVE n" text over the frozen playfield, holds 36 frames (1.2s)
- [ ] End screen: final score and wave reached
- [ ] HUD (y=120-127): lives left, score centre, wave right
- [ ] Verify: full loop is playable start to finish, title → game → wave transition → ... → end → title

## Phase 7: Visuals & sound polish

- [ ] Apply palette: ship fixed white (7), enemy/enemy-shot/grid colours rotate per the 4-wave theme table in DESIGN.md
- [ ] Draw sprite 0 (ship, rocket wedge) and sprite 1 (enemy, wing silhouette), per the pixel data in DESIGN.md's Sprite rendering section
- [ ] Draw sprites 2-4 (shot straight/shallow/steep); wire the angle-to-sprite-and-flip lookup (`abs(θ)` thresholds at 12°/37°, `flip_x` on sign, `flip_y` for enemy shots) so both shot types share all 3 sprites
- [ ] Outer-tier enemies (33px arc) drawn via `sspr` at 10×10 instead of native 8×8; inner/middle tiers stay native
- [ ] Explosion particle effect on enemy death: a handful of short-lived particles (position + velocity + countdown) spawned at the enemy's death position, radiating outward and fading over a few frames, coloured to match the wave theme; no dedicated sprite, drawn with `pset`/`circfill` like the current shot/enemy placeholders
- [ ] Background scanline grid: 8 fixed rows at the y-values in DESIGN.md, foreground/mid/horizon colour banding
- [ ] SFX: ship fire (short/punchy, deliberately breaks from the atmospheric palette so hold-to-fire doesn't choke the 4 sound channels), enemy destroyed, player hit, enemy dive start, wave clear, game over (all atmospheric/sustained)
- [ ] Verify: play a full round with sound on; confirm every listed SFX fires at its correct trigger, shots visibly point along their travel direction, outer-tier enemies read as visibly bigger, and the ship stays visually identifiable against a re-tinting field

## Phase 8: Final token & performance check

- [ ] Confirm final token count is within the ~8,192 budget (second checkpoint, now including Phase 6/7's screens, sprites, and SFX on top of Phase 5's core-systems count)
- [ ] Confirm a full wave at the entity cap (32 hostile entities plus ~8 player shots) renders without frame drops, given the extra per-frame trig from angle-based movement and the per-frame grid redraw

## Future ideas (not scheduled)

Not part of any numbered phase; captured here so they aren't lost, not committed to a phase or a token budget yet.

- **Squad-diverse entrance patterns**: currently every enemy in phase 1 of the entrance orbits the same entry point `(D1X,D1Y)` at the same radius (`D1R`) and speed (`CSPD`), differing only by phase offset (`ca`) — visually uniform, one ring of dots circling one point. A future pass could split enemies into squads (by tier, or by spawn order) that orbit distinct points, radii, or speeds, or follow different entrance shapes entirely, so the top-of-screen entrance reads as several distinct groups arriving rather than one undifferentiated ring. No numbers decided yet: how many squads, what distinguishes them visually, and whether squad identity carries into formation (Phase 2) or attack behaviour (Phase 3) are all open. Revisit after Phase 7's sprite work, since squad identity likely wants a visual tag (colour or shape) to read clearly, and current placeholder visuals (single-pixel dots) can't support that distinction yet.
