-- lib/state.lua
-- gs (game state) transition with return-to-previous-state tracking
-- tokens: ~20
-- depends: none

-- deliberately not a full dispatch-table FSM: games 1/2/3/5 all handle gs via
-- plain if/elseif chains in their own _update()/_draw(), and a generic
-- table-of-functions dispatcher would cost more tokens per call than that
-- for the small state counts this jam's games actually have (see lib/PLAN.md's
-- "deliberately excluded" note on architectural-convention-not-code). the one
-- piece that's genuinely reusable is remembering which state an overlay was
-- opened from, for overlays reachable from more than one caller state.

gs=0
gsret=0

-- call: goto_state(3) -- switches gs, remembering the current value in gsret
-- for a plain transition you don't need to return from, just set gs directly
function goto_state(ns)
  gsret=gs
  gs=ns
end

-- call: return_state() -- switches back to whatever was active before the last goto_state()
-- a single-caller overlay (like 2.p8's help_on) doesn't need this, a plain
-- boolean flag is cheaper; this is for a state reachable from more than one place
function return_state()
  gs=gsret
end
