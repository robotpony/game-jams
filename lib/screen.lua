-- lib/screen.lua
-- blinking prompt-text helper
-- tokens: ~15
-- depends: none

-- call: if blink(2) then print("press x to start",...) end
-- hz=2 gives a 0.5s on/off cycle at any framerate; stateless, no update() call needed
function blink(hz)
  return (time()*hz)%2<1
end
