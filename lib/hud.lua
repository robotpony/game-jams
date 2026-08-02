-- lib/hud.lua
-- right-aligned text/number printing
-- tokens: ~15
-- depends: none

-- call: rprint("hp "..hp,127,121,7) -- rightx is the x the string's right edge should end at
-- generalizes 1.p8's score/level/timer and 3.p8's score right-align math
-- (pos - #str*4, 4px/char at the default pico-8 font width)
function rprint(s,rightx,y,col)
  print(s,rightx-#s*4,y,col)
end
