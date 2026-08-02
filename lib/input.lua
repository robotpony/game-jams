-- lib/input.lua
-- was any button just pressed this frame
-- tokens: ~15
-- depends: none

-- call: if any_btnp() then new_game() end -- title/end-screen "press any button" prompts
-- verbatim from 3.p8's any_btnp()
function any_btnp()
  for i=0,5 do
    if btnp(i) then return true end
  end
  return false
end
