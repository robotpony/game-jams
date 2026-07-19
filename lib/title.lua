-- lib/title.lua
-- shared jam title card: colour-swatch strip, jam name, per-game name, blink prompt
-- tokens: ~95
-- depends: blink() (screen.lua)

-- call from _draw(): if gs==<title> then draw_title_card("#1") return end
-- name is centred dynamically, so it works for any per-game string length
function draw_title_card(name)
  cls(5)
  local sw={7,10,11,3,6,8,1,0}
  for i=0,7 do
    rectfill(30+i*9,8,34+i*9,14,sw[i+1])
  end
  local l1="'26 WARPED GAME JAM"
  print(l1,64-#l1*2,26,7)
  print("PRESENTS",48,34,7)
  print(name,64-#name*2,62,7)
  if blink(2) then
    local l2="PRESS X TO START"
    print(l2,64-#l2*2,104,7)
  end
end
