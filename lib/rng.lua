-- lib/rng.lua
-- weighted choice (cumulative-threshold roll) + Fisher-Yates shuffle
-- tokens: ~45
-- depends: none

-- call: local v = weighted(vals,cum,total)
-- e.g. weighted({1,2,3,4,5},{40,65,80,95},100) -- reproduces 3.p8's rnd_col()
-- vals[i] is picked when the roll falls under cum[i]; cum must be ascending
-- and cum[#cum] should equal total (or less, to leave a residual chance for
-- vals[#vals] to also win rolls above the last threshold)
function weighted(vals,cum,total)
  local r=rnd(total)
  for i=1,#cum do
    if r<cum[i] then return vals[i] end
  end
  return vals[#vals]
end

-- call: shuf(t) -- shuffles t in place (Fisher-Yates)
-- verbatim from 1.p8's shuf(t)
function shuf(t)
  for i=#t,2,-1 do
    local j=flr(rnd(i))+1
    t[i],t[j]=t[j],t[i]
  end
end
