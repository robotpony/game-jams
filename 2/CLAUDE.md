# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

A Pico-8 game called "2 Mission" — an action/platform/puzzle game with Atari 2600 aesthetics, a vastly simplified remake of Impossible Mission (Epyx, 1984). The full spec is in [README.md](README.md), following [`../SPEC-FORMAT.md`](../SPEC-FORMAT.md).

**Status: in progress.** `2.p8` implements Phases 1–5 of [PLAN.md](PLAN.md): elevator shaft, floor generation (including corridors merged into the shaft screen, and the elevator only stopping at corridor floors), rooms, objects, search, jump, the lift-fall hazard, robots, the control room puzzle, win/loss/timer/score logic, screen-transition fades/flashes, a polished game-over screen, and the real bottom-strip HUD. Visual/sound polish (Phase 6: sprites, SFX, ambient music) and the token/performance check (Phase 7) aren't built yet — keep following README.md and [DESIGN.md](DESIGN.md) for those.

## Development

Pico-8 has no build system, package manager, linter, or test runner. The workflow is:

- Edit the `.p8` file in an external editor or inside Pico-8's built-in editor
- Run with `pico8 -run 2.p8` (requires Pico-8 installed)
- Or open Pico-8, then `load 2.p8` and press Ctrl+R to run

Verification is manual: load the cart and play it.

## Pico-8 Constraints

These constraints shape every implementation decision:

- **Token limit**: ~8,192 tokens total; code is compressed and must be counted aggressively
- **Display**: 128×128 pixels, 16-colour palette
- **Sprites**: 8×8 pixels each, 256 slots in the sprite sheet
- **Map**: 128×64 cells, shared memory with the bottom half of the sprite sheet
- **Sound**: 64 SFX slots, 4 channels
- **Lua variant**: Pico-8 Lua omits parts of the standard library; no `string.format`, use `tostr()`, `tonum()`, `sub()`, `#str`, `add()` for tables

## Design summary (from README.md and DESIGN.md)

- Player rides an elevator between 16 randomized floors (auto-stopping at each), then explores corridor-linked puzzle rooms (3 floors, centre lift, robots, searchable objects); a "both" floor leads to two independent rooms
- Robots have 3 behaviour patterns: stationary-look, patrol, chase (see DESIGN.md's Core system design); speed/density ramp up with rooms found
- Searching an object fills a 10-step progress bar (~1s/step, pausing rather than resetting if the player is hit) and yields +2 HP or a puzzle letter; one letter is guaranteed per each of the first 10 valid rooms, spelling a 10-letter secret word picked per seed from a 5-word list
- Win: submit the correct letter arrangement in the control room (behind the shaft's last valid room). Loss: timer (300s) reaches 0, or HP (starts at 5; robot hit −1, fall −3, wrong submission −1) reaches 0
- All values are finalized in README.md and DESIGN.md (health/damage amounts, timer, palette, SFX, score formula); implement from those directly rather than re-deriving them

## Architecture (Phases 1–5)

`2.p8` implements the standard Pico-8 callback structure with the title screen, elevator shaft (corridors included), puzzle rooms, the control room, and game over all built:

```lua
_init()   -- gs=0 (title), trans_t=0, flash_t=0
_update() -- flash_t tick (always); title input; gs=4 input; timer tick + loss check;
          -- update_control() (gs==3); update_room() (gs==2); elevator move/auto-stop/wall-walk (gs==1)
_draw()   -- title card; draw_gameover() (gs==4); draw_control() (gs==3);
          -- draw_room() (gs==2); shaft scroll + rendering (gs==1); draw_overlay() after every branch
```

`gs` values: 0=title, 1=elevator shaft, 2=puzzle room, 3=control room, 4=game over.

**Floor/room generation** — `gen_floors()` seeds `lseed=flr(rnd(32767))`, `srand(lseed)`, then rolls `floors[i]` (1–16) as 0=neither, 1=left, 2=right, 3=both (both = 2 independent rooms toward the total). Re-rolls the seed until `nrooms>=wlen`, capped at 50 tries as a safety net (expected rooms per 16 floors is well above 10, so this practically always resolves on the first try). `wlen=#words[1]` (all 5 words are 10 letters, so any of them works as the canonical length) drives both this threshold and the `idx<=wlen` letter-assignment cutoff later in the same function — deriving both from the same value, rather than hardcoding `10` in two places, is what makes solvability (room count always covers the word length) structurally guaranteed instead of just true by coincidence.

**Floor spacing (bug fix)** — The independent per-floor roll above has no spacing awareness, so back-to-back valid floors were common (each floor is independently ~75% likely to be valid). A second pass after the roll walks `floors[2..nf]` and blanks out the second floor of any back-to-back valid pair, but only while `slack` (`nrooms-wlen`, the room count generated above and beyond the puzzle's actual minimum) can absorb the loss — `rc` (1 or 2, matching that floor's room count) is deducted from both `slack` and `nrooms` each time a floor gets blanked, so this can never drop the shaft below the room count the puzzle needs. Since a typical roll's expected `nrooms` is well above `wlen` (each floor independently averages ~1 room, so ~16 across the shaft against a floor of 10), there's usually enough slack to break up most or all clusters. Pre-existing runs of 2+ blank floors from the original roll are left untouched — this pass only ever adds gaps, it doesn't trim existing ones — which is where "sometimes more than 1 blank floor" comes from.

**Elevator vertical movement** — `cy` is the car's continuous world y; `cfloor`/`targety` track the discrete floor and its target y. Holding up/down (`btn(2)`/`btn(3)`) only responds while `spx` is within the narrow column (`carl` to `carr-7` — see Shaft walking); it calls `next_stop(dir)` rather than just `cfloor+dir`, so the car skips over "neither" floors and only ever targets one with a corridor. `next_stop` scans floor-by-floor in the given direction until it finds one where `floors[i]~=0`, or runs off the shaft's physical end (in which case the car just doesn't move — it can never park on a "neither" floor, even at floor 1 or 16). Arrival (`cy==targety`) snaps `moving=false` and re-clamps `spx` via `shaft_bounds()`, in case the new floor's corridor layout differs from the one just left.

**Shaft walking & corridors (merged into the shaft screen)** — `spx` is the player's x within the shaft screen, normally clamped to the narrow 16px column (`carl`=56 to `carr`=71), but `shaft_bounds()` extends that range out to the screen edge (0 or 120) on whichever side the current floor (`floors[cfloor]`) has an open corridor. There's no separate corridor screen: walking off the narrow column into an open side just keeps going, using the same `spx` movement, until it reaches `spx<=0` (left) or `spx>=120` (right), which calls `enter_room()`. A side with no corridor keeps `shaft_bounds()` clamped at the column edge, so movement just stops there (blocked, matching the solid wall drawn that side).

**Camera** — `camy=mid(0,cy-44,maxcamy)` centres the car vertically and clamps to the shaft's total height (`nf*fh`) minus the 112px playfield, so the view never scrolls past the top or bottom floor.

**Rendering** — `carl`/`carr` bound the shaft's interior column, where the car (`rectfill`+`rect` outline, sky blue/white) travels, with the player sprite (`pspr()`, see Player sprite below) drawn at `spx` on top of it. Per floor, each side independently renders one of two looks: a closed side gets the solid `wt`-thick navy wall plus, beyond it, `draw_concrete()`'s grey coursed-mortar-and-speckle backdrop (drawn once for the full shaft height, before the per-floor loop); an open-corridor side instead gets that whole span (from the shaft column to the screen edge) painted blank/black, overwriting the concrete there, with a thin white door frame at the true screen edge (x=0-3 or x=124-127), a light-grey floor/ceiling line at both the top and bottom edge of that floor's band (colour 6; bug fix — these were originally colour 1, the same near-black navy as the wall/concrete, so they were technically drawn but not perceptible against the black corridor fill), and a 2px yellow light bar at the shaft-column edge (`carl-2` to `carl-1`, or `carr+1` to `carr+2`) marking that side as exitable, visible from inside the narrow column itself rather than only at the far screen edge. Furniture/robot/player sprites are real art (Phase 6); the shaft/room backdrop itself (walls, floor lines, the lift platform) is still flat rects, not sprites. The shaft's original debug HUD (seed, current floor, room count) is gone, replaced by `draw_hud()` (see below); `lseed` is still a global if it's ever needed from the Pico-8 console, it's just not printed to screen anymore.

**Room/object generation** — `gen_floors()` also builds, per seed: `word` (one of the 5-word list), and `rooms` (array indexed 1..nrooms, one entry per valid corridor in shaft order — a "both" floor adds its left room before its right). `roomL[i]`/`roomR[i]` map a shaft floor back to its room index. `gen_room(letter)` rolls one of 4 density patterns (`objp` thresholds) and places 0-2 objects per of the room's 6 floor-sides (3 floors × left/right of the lift); if `letter` is non-nil (room index <=wlen) it's assigned to one random object in the room (force-adding one object first if the room rolled zero). Every non-letter object always yields health; nothing is ever truly empty.

**Room persistence** — `rooms[idx]` is generated once in `gen_floors()` and never regenerated; `enter_room()` just points `cur_room` at the existing table (and `cur_idx` at its index, for the exit call), so `obj.found`/`obj.prog` mutations from a previous visit are still there.

**Room entry/exit side** — `enter_room(idx,side)` spawns the player at `px=116` for `side==0` (left corridor: the room is to the shaft's left, so the player arrived walking left and is now beside the room's *right* wall, continuing left to go deeper) or `px=4` for `side==1` (mirror image). Exiting reverses this: `entry_side==0` requires walking right off `px>=120` (deeper is left, so leaving means backtracking right), `entry_side==1` requires walking left off `px<=0`. Either sets `gs=1` directly (no intermediate screen) and places `spx` at the matching shaft edge (0 or 120) to resume from.

**Transition pause** — `trans_t` (frames remaining) is checked first thing in `_update()`; while positive it just decrements and returns, freezing all game logic for that many frames while `_draw()` keeps rendering the new screen normally. Set to 9 (~300ms at 30fps) by `enter_room()` and by the room's exit code, so both directions of the shaft↔room crossing pause briefly on arrival. Elevator floor stops don't set it.

**Door SFX** — Plays once per shaft↔room crossing, both directions: inside `enter_room()`, and inside the room's exit-check right before `gs=1`.

**Centre lift (rideable)** — `lifty` bounces between `topy`/`boty` (the top and bottom floor's stand-level, `liftys[]`) at `liftspd` px/frame, pausing for `liftpause` (30 frames, ~1s) whenever it reaches any of the 3 floor-aligned y values (`topy`, `boty`, or the middle floor's `liftys[2]`, checked in `update_room()`'s first block, before anything else runs each frame). `lift_near(fl)` checks alignment within `liftt` px (8) against a specific floor's stop position; walking into the lift's column while `lift_near(rfl)` boards it (`ronlift=true`, `py` tracks `lifty` every frame).

While riding (`ronlift`), movement and jumping now work exactly like standing on any floor or corridor — bug fix, post-Phase 6: disembarking used to require directional input while `lift_near` was true for *some* floor (`lift_near(0) or lift_near(1) or lift_near(2)`), which meant the lift was completely unresponsive to input whenever it was mid-transit between stops, and jumping was impossible while riding at all. Now: horizontal input always moves `px` (with `pft`/`pdir` tracked the same as normal walking, so the run animation and footstep SFX both work while riding); walking off either edge of the lift's column (`liftx0`/`liftx1`) disembarks regardless of the lift's current alignment, snapping to `nearest_floor(lifty)`. `btnp(2)` launches a normal jump from the lift's current height (`jy0=py`, `rfl=nearest_floor(jy0)` so the landing/fall-gating logic downstream has a sensible floor reference), letting the player jump off it deliberately rather than only being able to walk off. Catching the lift again mid-arc (in the `jumping` branch) now checks height proximity (`abs(py-lifty)<=4`) instead of `lift_near(rfl)` — a floor-stop check — so a jump can catch the lift whether it's paused or actively moving, and can just as easily miss it if it's elsewhere, falling/landing per the usual jump logic.

**Jumping onto the lift (bug fix)** — Landing a jump used to only ever check the gap column at the fixed end of the 24-frame arc (`jt>=jT`), and only to decide whether to trigger a fall; it never checked whether the lift was actually *there*, so a directed jump (`jdir~=0`) could never land ON the 12px-wide lift platform in the first place — the arc's ~19px horizontal reach is deliberately wider than the gap specifically so it clears the hazard, which structurally means it always overshoots a stationary target inside that same gap. `update_room()`'s `jumping` branch now checks every frame of the arc (not just the last one): if the player's current x crosses the gap column while the lift is close by vertically (`abs(py-lifty)<=4` — height proximity, not a floor-stop check, so this also catches a lift that's actively moving, not just paused), the jump ends immediately and boards the lift (`ronlift=true`, `py=lifty`) right where it caught it, rather than carrying through to the far side. This is what makes "jump onto the lift" possible at all — catching it mid-flight, not landing precisely on it at the arc's end. The catch check only activates once `jt>=4` — bug fix, post-Phase 6: a jump launched *from* the lift itself starts with `py` and `cx` already inside the catch tolerance (the parabola has moved only ~3px by `jt=1`), so every jump off the lift was instantly re-caught and re-boarded on its first or second frame, making it impossible to actually leave. The 4-frame grace window is well before a normal floor-launched jump could realistically reach the gap column, so it doesn't affect catching the lift from elsewhere.

**Lift shaft visuals** — `liftx0`/`liftx1` (58/69, 12px) are the single shared bounds for both the visual gap and the platform, on the top and middle floors (`fl` 0 and 1): each of those floors' ground line (drawn in `draw_room()`) is split into two segments, `x=0-(liftx0-1)` and `x=(liftx1+1)-127`, leaving that column permanently blank rather than drawing a floor line across it — that gap is the visual "you can fall down here" cue matching the fall-through hazard below. The bottom floor (`fl==2`) instead draws one continuous line across the full width, no gap — bug fix, post-Phase 6: it originally split the same way as the other two floors even though the bottom floor has no floor below it to fall to, so the gap there was purely cosmetic and misleading. The lift itself renders as a short, wide platform (`rectfill(liftx0,lifty+5,liftx1,lifty+7,12)`, 3px tall) spanning `liftx0`/`liftx1` regardless of which floor it's at, reading as a floor slab rather than a solid block; its bottom row lands exactly on the same y as the ground line whenever the lift is aligned with a floor (on the bottom floor this just means the platform sits flush with the already-solid ground, not plugging anything). `liftx0`/`liftx1` are also what the boarding, disembarking, and fall-through checks below use for `cx`.

**Jump in rooms** — `jumping`/`jt`/`jT`(24)/`jh`(18)/`jdir`/`jy0` implement a fixed parabolic arc: `btnp(2)` (the up-press edge, not held) starts one whenever the player isn't in front of a searchable object (`fo==nil` at that instant — reaching the trigger check at all already implies that, since the search branch above it returns early on `btn(2) and fo`), reading `jdir` from whichever of `btn(0)`/`btn(1)` is held that frame (0 if neither, matching "straight up if the player isn't moving"). Up is otherwise unconditional — the only other place it does something else in a room is the `ronlift` branch (disembark input), which `return`s before this trigger is ever reached, so "up always jumps except on the lift/searching" falls out of code order rather than an explicit guard. Each frame while `jumping`, `jt` advances, `px` moves by `jdir*0.8` (~19px total over the jump), and `py` follows `jy0 - jh*4*jt*(jT-jt)/(jT*jT)` — the standard 0-at-both-ends, peak-`jh`-at-the-midpoint parabola, needing no gravity/velocity state. 24 frames and 18px peak height are deliberately more than a minimal hop needs, so the arc clears an 8px robot or the 12px lift gap (see Lift shaft visuals above) with margin instead of exactly matching it (an initial pass under-scoped this to a bare 8px/16-frame hop that only just cleared either hazard). The whole branch `return`s early, so normal walking is skipped while airborne, and the only way to leave it early is catching an aligned lift mid-flight (see Jumping onto the lift below) — otherwise that's what "clears it safely" means in practice for the mid-arc frames. Landing (`jt>=jT`, only reached if the mid-flight lift check didn't already end the jump) snaps `py=jy0` exactly, clears `jumping`, and (see Falling below) checks whether the landing `px` is in the gap column; the player returns to the same floor (`rfl` doesn't change from a jump) unless that check enters the `falling` state. The sprite flip mentioned in the spec now has real art (Phase 6): `pspr()` picks from a 4-frame launch/tuck/extend/land sequence, mirrored per `jdir`, based on `jt`/`jT` arc progress.

**Jump in the elevator shaft (corridors)** — the same `jumping`/`jt`/`jT`/`jh`/`jdir` globals drive a parallel jump implementation in `_update()`'s `gs==1` branch, triggered the same way (`btnp(2)`) once the shaft-column control check (`spx>=carl and spx<=carr-7`) has had its chance to consume the up-press for moving the car instead — that check always `return`s when up is pressed inside the column (even if the car can't actually move further), so reaching the jump-trigger check at all already means the player is out in a corridor, not in the column; no separate "am I in a corridor" guard is needed. There's no room-equivalent `py`/`jy0` here since the shaft player's y is always derived from `cy` (the car's position), not an independent value, so the jump only moves `spx` (clamped through `shaft_bounds()`, so it still respects a closed wall same as walking) and still triggers `enter_room()` on reaching an open door edge, same as normal corridor walking. `_draw()` computes a purely cosmetic vertical offset (`jh*4*jt*(jT-jt)/(jT*jT)`) applied to the player square's y so the arc is visible; nothing else about the corridor changes during a jump, since there's no hazard there to clear — it's just a faster crossing. (First Phase 3 pass omitted this entirely: pressing up in a corridor did nothing, since jump only existed inside `update_room()`.)

**Falling (`falling`)** — walking into the misaligned lift column (not `lift_near(rfl)`), or landing a jump inside it, on the top or middle floor only (`rfl<2`) and while not invulnerable (`invt<=0`), starts a real descent rather than an instant fail. `fall_from` records which floor the descent started from (0 or 1; the trigger sites simply don't fire at all when `rfl==2`, `elseif rfl==2 then px=nx` instead, so the bottom floor's gap columns are just normal walkable ground — bug fix, post-Phase 6: this used to be a hazard on every floor including the bottom one, with no floor below it to justify a fall). Each frame while `falling`, `py+=fallspd` (3px/frame) and normal left/right input still moves `px` (updating `pdir` same as walking), so the player can drift out of the gap under momentum exactly like a real fall. Three outcomes are checked every frame, in order: (1) if the actual lift is close by vertically (`abs(py-lifty)<=4`), the player lands on it (`ronlift=true`, `py=lifty`) regardless of pattern/pause state, catching it mid-transit not just mid-stop; (2) if `px+4` has drifted outside the `liftx0`/`liftx1` column, the fall ends safely on whichever floor's band the current `py` has reached (`fall_floor(py)`, comparing against `fly[]`'s band boundaries), landing at that floor's ground level — this is what lets sideways momentum carry the player onto a lower floor instead of falling all the way; (3) only if `py` reaches the bottom floor's ground level (`floor_ground(2)`) while still inside the column does the fall resolve as a landing-with-damage: `hp-=(fall_from==0 and 2 or 1)` (2 HP from the top floor, 1 from the middle), `invt=45`, and the player is placed standing at `rfl=2`, `py=floor_ground(2)-7` — in place, not reset to the room's entry door (bug fix, post-Phase 6: an earlier pass used a flat 3 HP and reset to the entry door regardless of fall distance, inherited from this mechanic's original instant-fail design). A player with no horizontal input at all falls straight down and always hits case 3, since `px` never leaves the column — matching "no momentum, no escape."

**Robots (`cur_room.robots`)** — generated in `gen_room()` alongside objects: each of the room's 6 floor-sides independently rolls a robot via `robp[pat]` (a % chance, indexed by the same density pattern that drives that room's object counts, so denser rooms get more of both), capped at 1 per side by construction (it's a single roll, not a loop). Pattern is uniform-random 1-3 (stationary/patrol/chase) independent of density. `update_robot(r)`, called for every robot every frame regardless of player state, opens by computing `lo,hi=r.side==0 and 4 or 72, r.side==0 and 50 or 119` — the same per-side span patrol always used for `r.x0`/`r.x1` (now folded into this shared computation instead of stored per-robot), reused as the movement clamp for all 3 patterns so a robot can never walk across the centre lift gap (`liftx0`/`liftx1`, 58-69) onto the room's other side, regardless of pattern. `hi` was originally 56/124 — bug fix, post-Phase 6: with an 8px-wide sprite, 124 let a robot's right edge reach x=131 (past the 127px screen) and 56 let it reach x=63 (into the 58-69 gap); both are now tight enough to keep the full sprite clear of the screen edge and the gap. `base_spd` (0.6, before this fix) was also halved to 0.3, reported as roughly twice too fast.

Each robot also rolls a `skin` (0-2, `flr(rnd(3))`) picking its sprite block via `skinbase={19,36,39}` (indexed `skinbase[skin+1]`, each block laid out neutral/lit-left/lit-right same as the player's run pairs). Skins 0 and 1 (red/dark-red/white, and solid red/yellow) were the only two for most of Phase 6; skin 2 (purple body, white lights, sprites 39-41) was added after a play-test question revealed both original skins were red-based and read as a single colour at a glance despite being two nominally-distinct variants.

Sound cycle (post-Phase 6): every look/turn event plays SFX slot 7 ("bleep-bloop") on channel 0 — the stationary pattern's flip, patrol's turn at either end, chase's "thinks" pause, and (new, see below) chase's direction-change pause. Actively moving (patrol, chase, or fleeing) plays slot 8 (a buzz blip) roughly every 8px of travel, checked as `flr(r.x)%8<1` rather than a new per-robot timer — since `r.x` increases by less than 1px/frame and `flr()` of a continuously-increasing value passes through every integer, this reliably fires once per ~8px regardless of the robot's current speed. Both slots share channel 0 (otherwise unused) across every robot in the room; this is a jam-scope simplification, not true per-robot polyphony, so if two robots' sounds would overlap only the most recently triggered one is actually heard.

Chase's direction change now pauses like patrol's turns do — bug fix, post-Phase 6: it used to recompute `r.dir=px>r.x and 1 or -1` and move in that new direction the same frame, so a robot could reverse instantly and repeatedly if the player lingered near its `r.x`, with no equivalent to patrol's pause-at-turn. The chase branch now compares the newly computed direction against `r.dir`; if it changed, the robot pauses (`r.t=10`, plays slot 7) instead of moving that frame, and only resumes movement (and the slot 8 buzz) once `r.t` runs out with the direction unchanged:
- **Stationary** (`pat==1`) — flips `r.dir` every 30-90 frames (`r.t` countdown), no movement; this is the look-left/right cue. The look SFX from README's spec is Phase 6 work (see SFX slots below), not wired up yet — only the visual flip.
- **Patrol** (`pat==2`) — walks between `lo`/`hi` (its spawn side's floor span) at `r.spd*rmul()`, reversing and pausing 15-45 frames (`r.t`) at each end.
- **Chase** (`pat==3`) — while `r.fl==rfl`, moves toward `px` at `r.spd*rmul()`, clamped to `lo`/`hi` same as patrol — a robot chasing from its own side simply stops at the gap rather than following the player across it. If the player is `jumping` and overlaps the robot's x (`abs(px-r.x)<=6`) and it hasn't already triggered this pass (`r.jumped`), it "thinks" for 30 frames (`r.t`, no movement) then flees the player's x for 20 frames (`r.flee`, also clamped to `lo`/`hi`) before resuming the chase; `r.jumped` resets once the player's x moves away, so a second jump-over later in the same encounter can retrigger it.

Each robot's `spd` is randomized at generation (`base_spd*(0.7 to 1.3)`), matching README's "moves at a random speed" for chase; `rmul()` — `1 + min(nvisited,10)/10` — is the shared difficulty-ramp multiplier applied on top of that at movement time (see Difficulty ramp below), so already-generated robots speed up live as the run progresses rather than needing regeneration.

**Player/robot collision (`hit_check()`)** — called once per frame, unconditionally (works during jump and while riding the lift too, since it's just an AABB test against the player's *current* `px,py` — a jump's elevated `py` or the lift's `py=lifty` naturally miss a floor-level robot's box without any jump/lift special-casing). While `invt>0` it just ticks the timer down and skips the check. Both boxes are inset 2px on every edge (`r.x+2` to `r.x+6`, `r.y+2` to `r.y+6` for the robot; `px+2` to `px+6`, `py+2` to `py+6` for the player, tested as `px<r.x+4 and px+6>r.x+2 and py<r.y+4 and py+6>r.y+2`) — bug fix, post-Phase 6, two passes: the first inset only the robot's side by 1px, which turned out insufficient (still triggered 2-4px before the sprites visually touched, since the player's own box was still the full 8x8); this pass tightened the robot's inset to 2px and added the same 2px inset to the player's side. On a hit: `hp-=1`, `invt=45`, and a small knockback shoves `px` 6px away from the robot. The player sprite flickers (`blink(10)`) while `invt>0` as the visual invulnerability cue.

**Difficulty ramp** — `nvisited` (0-10) increments the first time each room is entered (`cur_room.seen` guards against re-counting a revisit), tracked via `enter_room()`. `rmul()` turns that into the DESIGN.md formula `1 + rooms_found/10` and is applied to robot movement speed live, every frame, rather than baked into `r.spd` at generation. Density is deliberately *not* re-scaled by `nvisited`: all rooms are generated upfront in `gen_floors()` before any room has been visited (0 rooms found at that point), so there's no live "rooms found so far" signal available at generation time to scale density against. Each room's density pattern (1-4, chosen once at generation, drives both `objp` and `robp`) is the only density lever this cart has; that's a scope call against DESIGN.md's prose ("robot speed **and density** scale up"), following its precise formula (`robot_spd` only) as the more authoritative source over the looser prose description.

**Search** — `sobj` (or nil) is the object currently being searched, recomputed fresh every frame rather than toggled: each frame finds the front, unfound object on `rfl` within `abs(px-o.x)<=6`, and only advances (`prog+=2`, sets `sobj`) while `btn(2)` is held that same frame; a tick plays (SFX slot 5) each time `prog` crosses a 30-unit step boundary. Releasing up, walking away, or the floor changing all just stop the increment — `prog` lives on the object itself, so it's never lost, only paused. At 300 (10 steps, `prog+=2`/frame so 150 frames / ~5s total — doubled post-Phase 6 from an initial `+=1`/300-frame pass that felt slow) it plays a celebratory major-chord arpeggio (SFX slot 6, distinct from the per-step tick) and yields (`inv` gets the letter, or `hp` gets +2 capped at 5), marking `obj.found=true`. Finding a letter also sets `found_letter`/`found_t=60`, drawn as a brief "found: X" popup in `draw_room()` (box + the letter tile sprite + the actual letter) — post-Phase 6 fix, since `add(inv,fo.letter)` previously gave no feedback at all. Searching pre-empts movement, lift-boarding, and jumping entirely (an early `return` while `btn(2) and fo`); jumping is checked afterward via `btnp(2)`, so a held-up search always wins over a fresh up-press when both are momentarily true.

**HUD (`draw_hud()`)** — Shared by the shaft and room screens (both call it at the very end of their own draw function, the shaft after its `camera()` reset back to screen-absolute coordinates). Draws its own panel first (post-Phase 6, bug fix — it used to print directly over whatever the scene left behind, the same plain white text as everything else): a light-grey border line at `y=111` and a dark-blue fill (`rectfill(0,112,127,127,1)`) underneath both text lines, so the HUD reads as a UI layer rather than blending into the room/shaft. Line 1 (`y=113`; bug fix — was `y=112`, which put the text close enough to the `y=111` border line to visually run into it): `"time"` label (colour 6, dim) then `flr(timer/30)` (colour 7, bright) left-aligned, `"floor "..cfloor.."/"..nf` right-aligned (`126-4*#fl`, using the standard 4px/char advance this file already relies on elsewhere, e.g. `draw_title_card`'s centring), also colour 6. Line 2 (`y=120`): `"letters "..#inv.."/"..wlen` (colour 6) with `"hp "..hp` (colour 8, red) printed separately further right. DESIGN.md's ASCII mockups spec exactly these two lines for both screens and don't reserve a slot for hp; rather than drop hp entirely (it's the loss-condition stat, genuinely useful to see continuously) or add a third line the 16px bottom strip doesn't have room for, it rides along on the letters line instead — a presentation call within an otherwise-followed spec, not a new game-balance value. The control room does *not* use this function; DESIGN.md treats it as a distinct puzzle-arrangement UI rather than a physical room, and it already prints its own hp/time pair in its own layout.

**Control room entry (deep wall)** — Every room already has one impassable "deep" wall opposite its entry door (the far edge the player never reaches under normal play, since `px` is clamped to 0-120 and nothing previously handled reaching that clamp). For the single room where `cur_idx==nrooms` (the last valid room generated, in shaft order — always a real room, whether or not it happens to carry a letter, since idx runs 1..nrooms independent of the `wlen` letter cutoff), reaching that deep wall while still walking into it (`entry_side==0` needs `px<=0 and btn(0)`; `entry_side==1` needs `px>=120 and btn(1)` — continuing the same direction the player entered with, not reversing) calls `enter_control()` instead of leaving it as a dead stop. This check sits inside the existing `if rfl==2 then ... end` block in `update_room()`, alongside (but before) the shaft-exit checks, since the two use opposite directions/edges and can't both fire the same frame.

**Control room (`gs==3`)** — `enter_control()` sets `slots={}` (array 1..wlen, each nil or an index into `inv`), `csel=1` (cursor over `inv`, the pool of collected letters), `ssel=1` (cursor over `slots`), plus the same `trans_t=9`/door-SFX pattern every other screen transition uses. `update_control()`: left/right (`btnp(0)`/`btnp(1)`) cycle `csel` through all of `inv` (1-indexed wraparound via `(csel-2)%#inv+1` / `csel%#inv+1`), including already-placed letters — placing one twice is simply a no-op (see below), not prevented at the cursor level, to avoid a second "skip used letters" pass. Up/down (`btnp(2)`/`btnp(3)`) cycle `ssel` through `slots` the same way. `btnp(4)` ("Z") toggles the targeted slot: clears it if occupied, otherwise places `inv[csel]` there provided that inventory index isn't already sitting in some other slot (checked by scanning `slots`). `btnp(5)` ("X") submits: builds a guess string from `slots` (unfilled slots contribute `"_"`, which can never equal a real letter, so an incomplete arrangement just reads as wrong rather than needing a separate completeness check) and compares it to `word`. A match sets `score`, `won=true`, `gs=4`; a miss costs 1 HP (`max(0,hp-1)`) and clears `slots` back to empty so the player re-places from scratch — README only requires "costs 1 HP, can be retried without limit," not that partial placement survives a wrong guess, and clearing is simpler than tracking which letters to leave in place.

**Timer & loss condition** — `timer` (frames remaining, starts at 9000 = 300s at 30fps, set in `new_game()`) ticks down once per frame centrally in `_update()`, after the `gs==0`/`gs==4` early-outs but before dispatching to `update_control()`/`update_room()`/the elevator logic — so it runs across gs 1/2/3 uniformly without each of those needing its own decrement. The same central spot checks `timer<=0 or hp<=0` and, if either, sets `won=false`, `score=0`, `gs=4` and returns before that frame's gameplay update runs. HP-reducing spots (`hit_check()`'s robot hit, the lift-fall hazard, a wrong control-room submission) all clamp with `max(0,hp-n)` so `hp` never reads negative in the one frame between the damage and the next frame's centralized check catching it.

**Game over (`gs==4`)** — `draw_gameover()` prints a win/loss headline (`won and "mission complete" or "mission failed"`) over a colour band (`rectfill(0,40,127,58,won and 11 or 8)`, green/red) and `score`, plus a blinking "press any button" prompt; `_update()`'s `gs==4` branch returns to the title screen (`gs=0`) on `any_btnp()`, matching the state table (game over exits to title on any button, title exits to a fresh `new_game()` on any button — two separate any-button presses, not one). `score` is set to `100*#inv+2*flr(timer/30)` on a win (inside `update_control()`'s submit check) or `0` on any loss path; this logic is unchanged from Phase 4, only the presentation is new.

**Screen-transition overlay (`draw_overlay()`)** — Called at the end of every `_draw()` branch (title, room, control room, game over, shaft), so it always renders on top regardless of which screen is active. Two independent effects:
- *Iris wipe* — while `trans_t>0` (the existing shaft↔room/control-room crossing pause from Phase 2), draws a black bar shrinking in from both the top and bottom (`h=flr(64*trans_t/9)`, so `trans_t=9` covers the full screen and `trans_t=0` covers nothing), revealing the already-switched screen underneath. This is a deliberate single-phase reveal, not a true fade-out-then-fade-in crossfade: `gs` switches the instant `enter_room()`/`enter_control()`/an exit fires, before `trans_t` starts counting down, so there's no "old screen" left to fade out by the time the overlay starts drawing — and a real crossfade would need a 4-level palette-remap table (16 colours × several darkness steps) that isn't worth the token cost for a jam-scope transition. Reads as "fades in/out" per DESIGN.md's one-line requirement at a fraction of the cost.
- *Start/end flash* — `flash_t` (frames remaining, ticked down unconditionally as the very first line of `_update()`, independent of `trans_t`/`gs`) draws a solid white full-screen rect while positive. Set to 6 in three places: `new_game()` (game start), the loss branch in `_update()` (timer or hp hits 0), and the win branch in `update_control()` (correct submission) — covering both "game start and end flash" cases from DESIGN.md. It's a hard flash-then-cut rather than a graduated fade, which is a fair reading of "flash" (as opposed to the iris wipe's smoother "fade in/out" language) and needs no extra palette table either.

### SFX slots

| Slot | Event | Notes |
| ---- | ----- | ----- |
| 0 | Elevator hum/buzz | Low triangle tone (pitch 0x10) with vibrato, looped over its full 32 steps; played on channel 1 while moving, stopped (`sfx(-1,1)`) on arrival |
| 1 | Shaft/room door | 4-note decaying noise hit (pitch 24→20, volume 5→0) then silence; one-shot, no loop; played on channel 2 whenever the shaft and a room connect, in either direction |
| 2 | Footstep | 2-note percussive click (noise wave, pitch 24→20, volume 3→1); played on channel 3 via `step_sfx()`, called from every movement branch (room, shaft/corridor, riding the lift) whenever `pft%12==1` — a fixed modulus against the run-cycle timer, landing roughly 2 steps per 4-frame run cycle regardless of which branch is moving the player |
| 3 | Jump ("sproing") | 4-note ascending run (sawtooth, pitch 0x10→0x28, pitch-slide effect between notes); played on channel 3 once at every jump launch (room, shaft/corridor, and jumping off the lift) |
| 4 | Landing | 2-note percussive thump (noise wave, pitch 8→6, volume 5→2); played on channel 3 once when a jump's arc completes (`jt>=jT`) in both the room and shaft/corridor jump implementations — not played when the arc ends early by catching the lift mid-flight, since that's a board, not a landing |
| 5 | Search progress tick | 2-note blip (square wave, pitch 0x24→0x20); played on channel 3 once per progress step, checked as `fo.prog%30==0` right after `fo.prog+=2` — since `prog` starts at 0 and always increments by an even number, every multiple of 30 (each of the 10 steps) is hit exactly, no separate step-tracking needed |
| 6 | Search completion | 4-note ascending major-chord arpeggio (square wave, root/third/fifth/octave: 0x18/0x1c/0x1f/0x24), fast speed so the notes blend chord-like; played on channel 3 once when `fo.prog>=300` |
| 7 | Robot look/turn ("bleep-bloop") | 2-note pulse-wave pair (pitch 0x28→0x20); played on channel 0 at every robot look/turn event — see `update_robot()`'s Robots entry below |
| 8 | Robot move buzz | 1-note phaser-wave blip (pitch 0x10); played on channel 0, retriggered periodically while a robot is actively moving |

### State variables

```lua
-- screen
gs        -- game state: 0=title 1=elevator shaft 2=puzzle room 3=control room 4=game over
trans_t   -- frames left in the shaft<->room arrival pause; freezes _update while >0
flash_t   -- frames left in the current start/end white flash; ticks down unconditionally
          -- every frame regardless of gs/trans_t, purely cosmetic (doesn't freeze _update)

-- floor/room generation
nf, fh    -- floor count (16), px per floor / car height (24)
lseed     -- current building's RNG seed
floors    -- array 1..nf, corridor type per floor (0/1/2/3)
nrooms    -- valid room count from the last generation (always >=wlen); the control room
          -- sits behind rooms[nrooms], the last one generated in shaft order
word      -- this seed's secret word (one of the 5-word list)
wlen      -- #words[1]; word length, also the letter-assignment cutoff and the minimum
          -- room count gen_floors() re-rolls for -- ties the two together structurally
rooms     -- array 1..nrooms, {objs={...}, robots={...}, seen} per valid room, generated once
roomL, roomR -- [shaft floor] -> room index, for corridor-entry lookup

-- elevator
cfloor    -- current floor index, 1-based
cy        -- car's continuous world y
targety   -- y of the floor currently being travelled to
moving    -- true while travelling between floors
spx       -- player's x within the shaft screen; column-clamped, or corridor-extended per shaft_bounds()

-- shaft layout (x-axis)
carl, carr -- shaft/car interior bounds (56, 71)
wt         -- wall thickness (4px)
cl, cr     -- wall's outer, concrete-facing x (52, 75)

-- camera
maxcamy   -- max camera y offset (nf*fh - playfield height)

-- player resources (persist across rooms)
hp        -- 0-5, +2 per health object (capped at 5)
inv       -- array of collected letters, in find order

-- room (valid only while gs==2)
cur_room  -- rooms[idx] for the room currently entered; {objs={...}, robots={...}, seen=}
cur_idx   -- that room's index, so exiting can hand it back to the shaft
entry_side -- 0=left corridor, 1=right; which edge the door/exit is on
rfl       -- player's current room floor, 0-2 (top-bottom)
px, py    -- player's room-local position
ronlift   -- true while riding the centre lift
sobj      -- object currently being searched, or nil
found_t   -- frames left showing the "found: X" letter popup; ticks down unconditionally
          -- in _update() like flash_t, so it decays even if the room is left mid-popup
found_letter -- the letter shown in that popup
fly, flh  -- y-top / height of each room floor (37,37,38)
liftys, topy, boty, liftspd, liftt -- lift's 3 floor-aligned y values, travel bounds, speed, near-alignment tolerance
liftpause -- frames left paused at a floor-aligned y; lift movement is skipped while >0
liftx0, liftx1 -- lift shaft x-bounds (58,69); shared by the blank floor gap, the platform render, and the board/fall-through checks
falling   -- true while descending through the lift gap on floor 0 or 1 (room-only,
          -- never triggered on the solid bottom floor); fallspd (3px/frame) and
          -- fall_floor(y) (which floor band a given py has reached) support this
fall_from -- which floor (0 or 1) the current fall started from; scales landing damage
          -- (2 hp from floor 0, 1 hp from floor 1) when the fall reaches the bottom

-- jump (jumping/jt/jT/jh/jdir shared by gs==1 corridors and gs==2 rooms; jy0 is room-only)
jumping   -- true while the jump arc is playing out
jt, jT    -- frames elapsed / total frames in the current jump (24)
jh        -- jump peak height, px (18)
jdir      -- horizontal direction for this jump, -1/0/1
jy0       -- room-only: py at jump start, the floor-ground y the player returns to on landing

-- player damage & difficulty (persist across rooms)
invt      -- invulnerability frames remaining; also gates the lift-fall hazard
nvisited  -- distinct rooms entered so far, capped at 10; drives rmul()
base_spd, robp -- robot base speed anchor; per-density-pattern % chance of a robot per floor side

-- control room (valid only while gs==3)
slots     -- array 1..wlen, each nil or an index into inv (which collected letter fills that blank)
csel      -- cursor into inv (left/right), the currently selected pool letter
ssel      -- cursor into slots (up/down), the currently targeted blank

-- timer, win/loss, score (persist across the whole run)
timer     -- frames remaining, starts 9000 (300s @ 30fps); ticks down across gs 1/2/3, never resets
won       -- true if gs==4 was reached via a correct control-room submission, not timer/hp hitting 0
score     -- 100*#inv + 2*flr(timer/30) on a win, 0 on any loss; shown on the gs==4 screen
```

## Reusable code

Check [`../lib/CLAUDE.md`](../lib/CLAUDE.md) for shared Lua snippets (input handling, screen flash/fade, state machine, tweening, collision, HUD, map queries, seeded RNG) before writing new utility code from scratch. Snippets are copy-pasted into this cart's `__lua__` section, not imported — inline only what's needed given the shared token budget.
