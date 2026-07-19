pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- 4: gyri -- phase 1: ship arc movement & radial shooting

CX,CY=64,25
SR=64
SC=0.19167
ST=0.00556
FCD=4
SSPD=4

-- lib/math.lua
-- pico-8's sin() is inverted (sin(x)==-sin(2*pi*x)) for its y-down screen
-- convention; negate the sin term so increasing a sweeps rightward. the
-- cos term is added, not subtracted, since the arc is a valley opening
-- upward (implied centre above the screen) rather than a dome.
function arc_xy(cx,cy,r,a)
  return cx-r*sin(a),cy+r*cos(a)
end

function _init()
  sang=0
  ft=0
  shots={}
end

function _update()
  if btn(0) then sang=max(-SC,sang-ST) end
  if btn(1) then sang=min(SC,sang+ST) end

  if ft>0 then ft-=1 end
  if btn(4) and ft<=0 then
    ft=FCD
    local sx,sy=arc_xy(CX,CY,SR,sang)
    local dx,dy=arc_xy(0,0,-1,sang)
    add(shots,{x=sx,y=sy,vx=dx*SSPD,vy=dy*SSPD})
  end

  for i=#shots,1,-1 do
    local s=shots[i]
    s.x+=s.vx
    s.y+=s.vy
    if s.x<0 or s.x>127 or s.y<0 or s.y>127 then
      del(shots,s)
    end
  end
end

function _draw()
  cls(0)
  local sx,sy=arc_xy(CX,CY,SR,sang)
  circfill(sx,sy,3,7)
  for s in all(shots) do
    pset(s.x,s.y,7)
  end
end
