-- lib/map.lua
-- map cell coordinate conversion + 8-neighbour scan
-- tokens: ~35
-- depends: none

-- call: local cx,cy = cell_xy(px,py) -- pixel position to map cell coords
function cell_xy(px,py)
  return flr(px/8),flr(py/8)
end

-- call: for i=1,8 do local nx,ny=neighbour(cx,cy,i) ... end
-- i: 1=n 2=ne 3=e 4=se 5=s 6=sw 7=w 8=nw (Moore neighbourhood, clockwise from north)
-- 8, not 4: 6/DESIGN.md's cellular-automata cave smoothing needs a full Moore
-- neighbourhood wall-count to relax into organic shapes; a 4-neighbour (von
-- Neumann) count instead produces blockier, more diamond-shaped caverns.
-- no separate tile_at() wrapper: mget(cx,cy)/mset(cx,cy,t) are already single
-- calls, same token cost as wrapping them, so callers use those directly
local ndx={0,1,1,1,0,-1,-1,-1}
local ndy={-1,-1,0,1,1,1,0,-1}
function neighbour(cx,cy,i)
  return cx+ndx[i],cy+ndy[i]
end
