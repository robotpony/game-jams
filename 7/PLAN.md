# Plan

Phased implementation checklist for `7.p8`, based on [README.md](README.md) and [DESIGN.md](DESIGN.md).

This is the largest build in the jam so far, mainly because of the two-role AI (Phase 8). Rules come first, playable and verifiable by two humans in Hotseat mode, before any AI code exists — that way a rules bug and an AI reasoning-about-that-rule bug are never being debugged at the same time. No token cuts are planned in advance; game 5 and game 6, the previous most-complex entries, both landed with real headroom (2,898/8,192 and 4,357/8,192), so Phase 10 measures the real number before anything gets decided.

## Phase 0: Hex grid foundation

- [ ] Hex grid data structure: 15×11 table of `{terrain, unit}` cells, odd-q offset coordinates
- [ ] Hex-to-pixel conversion and the reverse (pixel/cursor → hex), per DESIGN.md's Hex grid & coordinates math
- [ ] Neighbour-direction tables for even/odd columns
- [ ] Camera: follows a given hex, clamped to world bounds
- [ ] Terrain rendering: 6 terrain colours from the palette table, drawn as flat-top hex shapes
- [ ] Verify: the fixed scenario's terrain layout renders correctly and scrolls smoothly as the camera target moves across the whole grid (manual — needs a play test in Pico-8)

## Phase 1: Buy / Setup and the shop screen

- [ ] Unit stat table (5 units: move, cost, HP, direct atk/rng, def, indirect atk/rng/splash)
- [ ] Shop screen: cursor over unit types, add/remove one at a time, running point total, per DESIGN.md's Buy/Setup layout
- [ ] Placement: cursor-select a hex within the buyer's setup zone, drop a purchased unit there
- [ ] Sequential flow: Attacker buys+places, then Defender buys+places (both human in Hotseat mode for this phase's testing)
- [ ] Verify: both sides can spend their full point pool (Attacker 30, Defender 20), place every purchased unit only within their own zone, and can't overspend (manual — needs a play test in Pico-8)

## Phase 2: Movement & direct fire

- [ ] Movement: spend MP by terrain cost table, block on Water, block on occupied hexes
- [ ] First/Second Direct Fire phases: range + LOS check (LOS itself lands in Phase 3; stub as "always visible" for now), hit-chance formula, 1 HP damage per hit
- [ ] Return Fire: target fires back first if it hasn't fired yet this turn, using the same formula
- [ ] Unit death: HP reaching 0 removes the unit from its hex
- [ ] Verify: two hotseat players can move units, trade direct fire, and see HP drop and units die correctly (manual — needs a play test in Pico-8)

## Phase 3: Spotting & LOS

- [ ] Spotted/unspotted state per unit, set on move/fire-within-enemy-LOS or occupying non-blocking terrain in enemy LOS
- [ ] Reverts to unspotted at end of any phase if outside all enemy LOS
- [ ] Simplified LOS check: blocked by terrain on viewer hex, target hex, or the midpoint hex between them
- [ ] Direct fire targeting now requires the target to be spotted; unspotted enemy units aren't drawn at all
- [ ] Verify: a unit sitting in Forest/Town reads as unspotted until it moves or fires in enemy LOS, and disappears from the opponent's view once it reverts (manual — needs a play test in Pico-8)

## Phase 4: Indirect fire & artillery plotting

- [ ] Mobile Artillery Plot phase: pick a target hex, fires same phase-cycle (Indirect Fire)
- [ ] Artillery Plot phase (stationary): pick a target hex, fires next turn's Indirect Fire
- [ ] Drift roll: 0-3 hexes, random direction, applied at the moment of firing
- [ ] Splash: Mobile Artillery hits target hex only; stationary Artillery hits target + 6 adjacent hexes
- [ ] Verify: a plotted stationary Artillery shot correctly waits a full turn before landing, drift visibly moves the impact point, and splash damage reaches all 6 neighbours for the stationary type only (manual — needs a play test in Pico-8)

## Phase 5: Close assault

- [ ] Close assault move: an unfired Light/Medium Tank can move onto an enemy-occupied hex instead of a normal move
- [ ] Odds formula with all three modifiers (defender already fired, defender on defensive terrain, attacker below half HP), clamped 5-95%
- [ ] Single-roll resolution: loser removed outright, winner survives undamaged
- [ ] Verify: odds swing correctly with each modifier individually, and a resolved assault always removes exactly one of the two units (manual — needs a play test in Pico-8)

## Phase 6: Full turn sequence, reinforcements, and victory

- [ ] Wire all of Phases 2-5 into the real 8-phase turn sequence (`ph` counter within `gs==4`), matching DESIGN.md's Turn sequence section exactly
- [ ] Recurring reinforcements: Attacker +6pts/turn, Defender +4pts/turn, spent via the Phase 1 shop screen (no placement step — enter at a fixed reinforcement hex)
- [ ] Scoring phase: town VP awarded only when occupied exclusively by one side at end of turn
- [ ] Turn counter and 10-turn Standard-length limit; VP comparison decides the winner (or draw) at the limit
- [ ] Verify: a full 10-turn match runs start to finish in Hotseat mode, reinforcements arrive on schedule, towns score VP correctly, and the match ends with the right winner/draw (manual — needs a play test in Pico-8)

## Phase 7: Screens & flow

- [ ] Title screen (shared jam card, reused from `lib/title.lua`)
- [ ] Mode select: 1P vs AI / 2P Hotseat
- [ ] Role select (1P only): Attacker/Defender; 2P mode auto-assigns P1=Attacker, P2=Defender
- [ ] End screen: winner/draw headline, final VP both sides, turns played
- [ ] HUD: turn counter, current phase name, both sides' VP, all in the fixed 16px bottom strip
- [ ] State machine wiring: title → mode select → (role select →) buy/setup → playing → end → title
- [ ] Verify: the full loop is reachable and playable in both 1P (once Phase 8 lands) and 2P Hotseat modes (manual — needs a play test in Pico-8)

## Phase 8: AI

- [ ] Movement heuristic: step toward nearest uncontested town, or nearest spotted enemy if any are spotted; one adjacent-hex retry if blocked
- [ ] Targeting heuristic: fire at any spotted enemy in range, preferring the lowest-HP target
- [ ] Artillery-plot heuristic: target last known enemy position; hold fire if nothing's ever been spotted
- [ ] Close-assault heuristic: only initiate at ≥60% computed odds
- [ ] Reinforcement-buy heuristic: fixed priority list (Medium Tank, Light Tank, Infantry, Mobile Artillery, Artillery), spend while affordable
- [ ] AI can take either role, since 1P mode lets the human pick Attacker or Defender
- [ ] Verify: AI completes a full match against a human player without getting stuck (blocked movement, no valid target, etc.), for both AI-as-Attacker and AI-as-Defender (manual — needs a play test in Pico-8)

## Phase 9: Visuals & sound

- [ ] Real sprites: 5 unit types × faction colour (via `pal()` swap, red/teal, rather than duplicate art), 6 terrain hex tiles, authored via [`tools/sprites/`](../tools/CLAUDE.md)'s hex-def + `sprite_tool.py` pipeline
- [ ] SFX: direct fire hit/miss, indirect fire impact, close assault resolve, unit destroyed, town captured, turn advance, win/loss/draw
- [ ] Verify: every listed SFX fires at its correct trigger (manual — needs a play test in Pico-8; sound content authored by encoding, not by ear, since this pipeline can't play or hear Pico-8 audio — flag anything that sounds off)

## Phase 10: Token & performance check

- [ ] Confirm token count against the ~8,192 budget via `p8tool stats`; if over, decide cuts then, based on where the actual count landed
- [ ] Confirm AI turn processing (movement/targeting/artillery decisions across up to 165 hexes) doesn't visibly stall a turn
- [ ] Verify: a full match plays at a reasonable pace in both modes, and the final token count is recorded here once measured (manual — needs a play test in Pico-8)
