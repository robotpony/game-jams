-- lib/math.lua
-- arc position helper: polar-to-cartesian around an implied centre
-- tokens: ~20
-- depends: none

-- call: local x,y = arc_xy(cx,cy,r,a)  -- a in pico-8 turns, 0 = straight down
-- pico-8's sin() is inverted (sin(x)==-sin(2*pi*x)) for its y-down screen
-- convention, so this negates the sin term to keep "increasing a" sweep
-- rightward, matching a natural left/right mental model. the cos term is
-- added (not subtracted), since callers in this project put their implied
-- centre above the arc (a valley/U shape) rather than below it (a dome).
-- a unit direction vector (not a position) is the same call with cx=cy=0;
-- r=1 gives the outward direction (away from centre), r=-1 gives inward.
function arc_xy(cx,cy,r,a)
  return cx-r*sin(a),cy+r*cos(a)
end
