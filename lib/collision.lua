-- lib/collision.lua
-- axis-aligned overlap check for two pixel rects
-- tokens: ~25
-- depends: none

-- call: if rect_hit(px,py,8,8,ox,oy,8,8) then ... end
-- (x,y) is each rect's top-left; true when the two rects overlap at all.
-- generalizes the inline checks 3.p8 (item catch) and 5.p8 (hazard/ladder)
-- each hand-rolled with hardcoded sizes.
function rect_hit(x1,y1,w1,h1,x2,y2,w2,h2)
  return x1<x2+w2 and x2<x1+w1 and y1<y2+h2 and y2<y1+h1
end
