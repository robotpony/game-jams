pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- 6: dug, dug, down. -- phase 1: world gen & camera. phase 2: mining.
-- phase 3: edge wrap. phase 4: combat & monsters. phase 5: inventory &
-- crafting. phase 6: chests & help. phase 7: screens & flow

-- lib/map.lua
function cell_xy(px,py)
  return flr(px/8),flr(py/8)
end

local ndx={0,1,1,1,0,-1,-1,-1}
local ndy={-1,-1,0,1,1,1,0,-1}
function neighbour(cx,cy,i)
  return cx+ndx[i],cy+ndy[i]
end

-- lib/rng.lua
function weighted(vals,cum,total)
  local r=rnd(total)
  for i=1,#cum do
    if r<cum[i] then return vals[i] end
  end
  return vals[#vals]
end

-- lib/input.lua
function any_btnp()
  for i=0,5 do
    if btnp(i) then return true end
  end
  return false
end

-- lib/screen.lua
function blink(hz)
  return (time()*hz)%2<1
end

-- lib/title.lua
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

-- lib/state.lua
gs=0
gsret=0
function goto_state(ns)
  gsret=gs
  gs=ns
end
function return_state()
  gs=gsret
end

-- world: 128x64 cell map. cell value 0=floor, 1-16=wall block id
-- (id order matches readme's block tier table: 1-4 tier1, 5-8 tier2,
-- 9-12 tier3, 13-14 hazard (lava/water), 15-16 special (vein/glowstone))
w=128
h=64
spd=1.5

-- sprite slot == block id (1-16), monster sprite slot == 16+typ, so no
-- id->colour lookup table is needed (see tools/sprites/manifests/g6.txt
-- for the full slot assignment)

function gen_world()
  glow={} -- glowstone cell coords, collected during pass 2 below; scanned
    -- each _draw() frame by visr() to extend the lit radius, instead of a
    -- per-frame full-map scan
  -- pass 1: cellular automata carves floor/wall shape (no continuous
  -- noise function; see design.md's world generation for why). double-
  -- buffered: each iteration computes into buf[][] and only copies back to
  -- the live map once the whole grid's been scanned. an earlier in-place
  -- version (no buf) let later cells read already-updated neighbours from
  -- the same pass, which cascaded wall density down to ~3% within 4
  -- iterations -- an almost-empty map (see 6/PLAN.md phase 1's playtest note)
  for cx=0,w-1 do
    for cy=0,h-1 do
      mset(cx,cy,rnd(100)<45 and 1 or 0)
    end
  end
  local buf={}
  for it=1,4 do
    for cx=0,w-1 do
      buf[cx]=buf[cx] or {}
      for cy=0,h-1 do
        local wc=0
        for i=1,8 do
          local nx,ny=neighbour(cx,cy,i)
          if nx<0 or nx>=w or ny<0 or ny>=h or mget(nx,ny)==1 then
            wc+=1
          end
        end
        -- tie-preserving 3-way rule: a >=5/<=3-only rule doesn't stabilize,
        -- it keeps eroding every iteration even with proper double-buffering
        if wc>4 then buf[cx][cy]=1
        elseif wc<4 then buf[cx][cy]=0
        else buf[cx][cy]=mget(cx,cy) end
      end
    end
    for cx=0,w-1 do
      for cy=0,h-1 do
        mset(cx,cy,buf[cx][cy])
      end
    end
  end
  spx,spy=find_spawn()
  -- near/mid distance-bucket thresholds, scaled to this run's actual spawn
  -- position rather than fixed constants: fixed thresholds (12/28) badly
  -- undersized every map -- spawn-to-corner distances range roughly 0-140
  -- cells depending on where spawn lands, so a fixed 28-cell "far" cutoff
  -- put ~80% of the map in the tier-3-favoured bucket, making tier 3 the
  -- *most* common block overall instead of the rarest (see 6/PLAN.md
  -- phase 1's playtest note)
  local maxd=0
  local corners={{0,0},{w-1,0},{0,h-1},{w-1,h-1}}
  for i=1,4 do
    local c=corners[i]
    local dx,dy=c[1]-spx,c[2]-spy
    local d=sqrt(dx*dx+dy*dy)
    if d>maxd then maxd=d end
  end
  neard,midd=maxd*0.25,maxd*0.55
  -- pass 2: every remaining wall cell gets a block id, distance-biased
  for cx=0,w-1 do
    for cy=0,h-1 do
      if mget(cx,cy)==1 then
        local id=pick_block(cx,cy)
        mset(cx,cy,id)
        if id==16 then add(glow,{cx,cy}) end
      end
    end
  end
end

-- randomized spawn within a margin from the map edges (see design.md's
-- spawn placement note); falls back to forcing a small floor pocket open
-- if 50 random tries all land on wall
function find_spawn()
  for i=1,50 do
    local cx=10+flr(rnd(w-20))
    local cy=6+flr(rnd(h-12))
    if mget(cx,cy)==0 then return cx,cy end
  end
  local cx,cy=flr(w/2),flr(h/2)
  mset(cx,cy,0)
  for i=1,8 do
    local nx,ny=neighbour(cx,cy,i)
    mset(nx,ny,0)
  end
  return cx,cy
end

-- block id for one wall cell: a small flat-rate roll for hazard/special
-- overlays first, then a distance-biased tier roll (weighted(), see
-- lib/rng.lua) for the common tier-1/2/3 material, sub-block picked
-- uniformly within that tier. tuning numbers are first-pass, see
-- design.md
function pick_block(cx,cy)
  local r=rnd(100)
  if r<2 then return 13+flr(rnd(2)) end -- 2%: lava or deep water
  if r<5 then return 15+flr(rnd(2)) end -- 3%: treasure vein or glowstone
  local dx,dy=cx-spx,cy-spy
  local d=sqrt(dx*dx+dy*dy)
  local cum
  if d<neard then cum={90,99,100}
  elseif d<midd then cum={40,85,100}
  else cum={10,45,100} end
  local tier=weighted({1,2,3},cum,100)
  local base=tier==1 and 1 or (tier==2 and 5 or 9)
  return base+flr(rnd(4))
end

-- floor (0) and both hazard ids (13 lava, 14 water) are passable; every
-- other id is a mineable/special wall and blocks movement until mined
function walkable(t)
  return t==0 or t==13 or t==14
end

-- edge wraparound (phase 3, see design.md): teleports across a boundary
-- to the mirrored coordinate on `newmajor` (0 or the far edge), sliding
-- along that edge to the nearest floor cell if the direct mirror lands
-- on wall -- common at the exact edge, since gen_world() counts
-- out-of-bounds neighbours as wall, biasing edge cells toward wall.
-- axis true=x-wrap (search varies cy over 0..lim-1); false=y-wrap
-- (search varies cx). caller never reaches this needing to search past
-- lim cells since the world always has floor somewhere on the world's
-- edges by construction (find_spawn()'s fallback forces some open)
function wrap_axis(axis,newmajor,minor,lim)
  local mc=flr(newmajor/8)
  local mcell=flr(minor/8)
  for r=0,lim do
    for s=-1,1,2 do
      local v=mcell+r*s
      if v>=0 and v<lim then
        local cx,cy=axis and mc or v,axis and v or mc
        if mget(cx,cy)==0 then return newmajor,v*8 end
      end
      if r==0 then break end
    end
  end
  return newmajor,minor
end

-- per-axis move + single-point (player centre) collision against wall
-- cells, so a blocked x doesn't also block a still-open y (sliding along
-- a wall rather than sticking). not full aabb (lib/collision.lua's
-- rect_hit is for a later phase's monster/hazard overlap); a point check
-- is enough for solid-terrain movement against an 8x8-aligned grid.
-- moving past either bound wraps to the opposite edge (wrap_axis) rather
-- than clamping in place, per phase 3. diagonal movement into a corner
-- that also needs wrap_axis's floor-search on the first (x) axis can
-- carry that adjusted py into the second (y) axis's check below, since
-- both axes still run sequentially against the live px/py -- an accepted
-- edge case, not a bug: it only nudges the landing spot to nearby floor
function try_move(dx,dy)
  local cx0,cy0=cell_xy(px+4,py+4)
  local espd=mget(cx0,cy0)==14 and spd*0.5 or spd -- deep water: movement penalty
  if dx~=0 then
    local nx=px+dx*espd
    if nx<0 then px,py=wrap_axis(true,w*8-8,py,h)
    elseif nx>w*8-8 then px,py=wrap_axis(true,0,py,h)
    else
      local cx,cy=cell_xy(nx+4,py+4)
      if walkable(mget(cx,cy)) then px=nx end
    end
  end
  if dy~=0 then
    local ny=py+dy*espd
    if ny<0 then py,px=wrap_axis(false,h*8-8,px,w)
    elseif ny>h*8-8 then py,px=wrap_axis(false,0,px,w)
    else
      local cx,cy=cell_xy(px+4,ny+4)
      if walkable(mget(cx,cy)) then py=ny end
    end
  end
end

-- tier lookup for mining: 1-4/15/16 -> tier1 (15/16 deliberately share
-- tier1's resistance(1)/hp(10) rather than a separate tier0, since design.md
-- gives treasure vein/glowstone the exact same resistance/hp as tier1 --
-- "always-breakable regardless of tool" falls out of that for free once
-- tool starts at 1 and never goes lower. 13/14 (hazard) return nil: not
-- mineable at all, handled instead by walkable()/lava contact below
function blocktier(id)
  if id<=4 or id==15 or id==16 then return 1
  elseif id<=8 then return 2
  elseif id<=12 then return 3
  end
end

hpmax={10,20,35}
toolpow={2,4,7,12} -- damage per mining tick, indexed by equipped tool tier
  -- (4th entry is runic pick's -- phase 2 only needed tiers 1-3, tier 4
  -- wasn't reachable until phase 5's crafting added it)

-- mining: hold o (btn(4)) while facing a block. tier gates whether the
-- equipped tool can damage it at all; once gated in, hp is chipped down
-- over ticks (not every frame -- see mtick) at the tool's power. mcx/mcy/
-- minehp/mtick track the single in-progress target; switching target
-- (moved, turned, or released) resets progress rather than persisting
-- per-cell, since only one block can ever be actively mined at once.
-- named minehp, not mhp, to avoid colliding with the per-type monster
-- max-hp table below (mhp={4,10,8,12,10,25}) -- that collision was a
-- real bug: mining a block reassigned the global mhp to a plain number,
-- so the next new_game() -> gen_monsters() crashed on mhp[typ] with
-- "attempt to index a number value" the moment a run mined anything
-- before restarting
function try_mine(tx,ty)
  local id=mget(tx,ty)
  local tier=id~=0 and blocktier(id)
  -- resist feedback (sfx slot 4) is rate-limited on its own counter, not
  -- mtick -- mtick only starts once a mineable target is actually set
  -- below, which never happens on this branch
  if tier and tool<tier then
    mcx=nil
    rtick+=1
    if rtick%15==1 then sfx(4) end
    return
  end
  rtick=0
  if not tier then mcx=nil return end
  if mcx~=tx or mcy~=ty then
    mcx,mcy,minehp,mtick=tx,ty,hpmax[tier],0
  end
  mtick+=1
  if mtick%6==0 then
    sfx(2) -- mining tick
    minehp-=toolpow[tool]
    if minehp<=0 then
      sfx(3) -- block break
      mset(tx,ty,0)
      mat[id]=min(99,(mat[id] or 0)+1)
      sfx(10) -- material pickup
      pushrecent(id)
      matcount+=1 -- scoring's materials_collected term (design.md), a running
        -- total distinct from mat[]'s current (crafting-consumable) counts
      if id==15 then add_coins(10) end -- treasure vein: readme's "guaranteed
        -- bonus drop" beyond the normal material, deferred from phase 2
        -- until coins existed to pay it out; first-pass amount
      mcx=nil
    end
  end
end

-- combat data, type ids 1-6 matching readme's monsters table order
-- (bat,crawler,slug,wraith,archer,warden); all first-pass per design.md
mhp={4,10,8,12,10,25}
mdmg={1,2,2,2,3,3}
mspd={0.6,0.26,0.19,0.68,0.3,0.38} -- 25% slower than the original first-pass
  -- values ({0.8,0.35,0.25,0.9,0.4,0.5}) -- playtest feedback (see 6/PLAN.md's
  -- phase 4 verify note): monsters read as uniformly too fast
mrng={0,0,3.5,0,5.5,3.5} -- 0=melee(contact only), >0=ranged engage range
  -- in cells, not pixels: pico-8's fixed-point numbers overflow squaring
  -- anything past ~181 (16.16 format's ~32767 ceiling), and this map is
  -- 1024x512px, so upd_mon/try_attack's distance checks work in cell
  -- units (divide by 8) to stay well under that -- see plan.md's phase 4
  -- bug note. warden's "melee + occasional ranged" is approximated as a
  -- short ranged tier (slug's) rather than real dual-mode ai -- a scope
  -- cut, not an oversight
aggrorng=6 -- cells; monsters ignore the player entirely (no chase, no
  -- attack) outside this radius -- playtest feedback that monsters chased
  -- from anywhere on the map, unlike mrng which only gates ranged attack
  -- range, not whether a monster notices the player at all
wpow={2,4,7,12} -- weapon damage per hit, indexed by equipped weapon tier
  -- (4th entry is runic blade's, same reason as toolpow's above)
guardthresh=12 -- frames x must be continuously held before guard engages
  -- (dmg_player checks xhold>=this) -- comfortably past a normal tap's
  -- length so a quick attack-tap never accidentally reads as a guard

-- visibility radii (cells). bumped from the original 4/6/7 after playtest
-- feedback that the hard-cutoff fog read as unclear/glitchy rather than
-- as darkness -- see the dither patterns below, which address the
-- clarity problem directly; the size itself was a separate "feels too
-- small" complaint, bumped once more (6/8/9 -> 7/9/10) after playtesting
-- the dithered version. no-stacking max() rule unchanged (glowstone/
-- lantern each extend the base, don't add to it). lanternr>glowr since
-- readme's recipe table crafts a lantern from 2 glowstone -- the upgrade
-- should out-light a single glowstone, not match it
baser,glowr,lanternr=7,9,10
-- fog dither patterns (fillp, transparency mode via the .1 suffix -- see
-- pico-8's fillp manual entry): more 1-bits means more transparent
-- (verified empirically, not assumed -- an earlier symmetric 50/50 test
-- pattern couldn't distinguish direction). patsparse is mostly-1s (still
-- see-through, light darkening) for the ring just inside the edge;
-- patdense is mostly-0s (mostly opaque) for the outermost ring, so the
-- edge reads as fading vision rather than the world abruptly stopping
patsparse=0b1110111011101110.1
patdense=0b0001000000010000.1

-- player sprite slot (23-30) from facing fx,fy (each -1/0/1, never both 0
-- once fx,fy=0,1 has run once in new_game()): key=(fx+1)+(fy+1)*3 gives
-- 0-8 skipping the unused 4 (fx=fy=0), one slot per one of the 8 readme
-- movement directions -- no flip_x reuse, each direction is its own
-- hand-drawn sprite (see tools/sprites/manifests/g6.txt)
pspr={[0]=30,[1]=24,[2]=29,[3]=26,[5]=25,[6]=28,[7]=23,[8]=27}

-- player draw: 3 layers composited at the same px,py via transparent-0
-- backgrounds, so a walk cycle and a weapon swing don't need a full
-- redraw of the whole 8x8 figure per frame (see the sprite-design
-- discussion this phase) -- legs (43-47) are shared across directions:
-- one idle pose, plus a 2-frame cycle for vertical movement (up/down and
-- all 4 diagonals, since fy~=0 covers all of those) and a separate
-- 2-frame cycle for pure horizontal movement (fy==0, left/right only).
-- walkt only advances while moving (see _update()), so flr(walkt/8)%2
-- naturally holds each frame instead of ticking while stationary
function draw_player()
  local legspr
  if not moving then legspr=43
  elseif fy~=0 then legspr=(flr(walkt/8)%2==0) and 44 or 45
  else legspr=(flr(walkt/8)%2==0) and 46 or 47
  end
  spr(legspr,px,py)
  spr(pspr[(fx+1)+(fy+1)*3],px,py)
  -- weapon overlay: mining (o held) shows the equipped tool, a recent
  -- attack swing or an active guard (atkt>0 or xhold>=guardthresh, both
  -- x-driven now) shows the equipped weapon -- reuses the existing
  -- item-icon sprites rather than drawing new art, offset toward
  -- whichever direction the player's currently facing
  if btn(4) then
    spr(tool<4 and 31+tool or 41,px+fx*6,py+fy*6)
  elseif atkt>0 or xhold>=guardthresh then
    spr(wtier<4 and 34+wtier or 42,px+fx*6,py+fy*6)
  end
end

-- 12 monsters, placed on random floor cells and tier-weighted by distance
-- from spawn (near/mid/far cum tables, same shape as pick_block's, reusing
-- neard/midd already computed in gen_world -- one distance-bias mechanism
-- for both blocks and monsters instead of two). tier picks a pair (bat/
-- crawler, slug/wraith, archer/warden), a coin flip picks within the pair
function gen_monsters()
  mon={}
  for i=1,12 do
    local cx,cy=flr(rnd(w)),flr(rnd(h))
    for t=1,20 do
      if mget(cx,cy)==0 then break end
      cx,cy=flr(rnd(w)),flr(rnd(h))
    end
    local dx,dy=cx-spx,cy-spy
    local d=sqrt(dx*dx+dy*dy)
    local cum
    if d<neard then cum={70,95,100}
    elseif d<midd then cum={30,75,100}
    else cum={10,50,100} end
    local tier=weighted({1,2,3},cum,100)
    local typ=(tier-1)*2+1+flr(rnd(2))
    -- per-instance speed variance (0.85x-1.15x of the type's mspd) so two
    -- monsters of the same type don't move in lockstep -- playtest asked
    -- for "some variation" beyond the existing per-type mspd table
    add(mon,{x=cx*8,y=cy*8,typ=typ,hp=mhp[typ],cd=0,spd=0.85+rnd(0.3)})
  end
end

function hpdmg(n)
  hp=max(0,hp-n)
  hflash=6 -- full-screen palette-tint flash, see _draw()'s pal() block
  sfx(0) -- player hit taken
  if hp<=0 then sfx(15) gs=4 end -- player death, over top of the hit sound
    -- above; end screen -- was a separate `dead` flag before phase 7's
    -- real state machine existed to hold this directly
end

-- guard (x, held past guardthresh frames): any monster damage landing
-- while xhold is that high is fully negated, checked here so melee and
-- ranged both route through the same gate. lava's hazard damage bypasses
-- this and calls hpdmg() directly -- guard is for monster attacks, not
-- terrain. replaces a tap-triggered timed parry window (see try_attack's
-- comment for why: that window and attack shared o, tap-vs-hold on one
-- button, which is exactly the ambiguity this whole revision removes)
function dmg_player(n)
  if xhold>=guardthresh then sfx(6) return end -- guard blocks a hit
  hpdmg(n)
end

-- one mover/attacker for all 6 types via the per-type mspd/mrng tables
-- above, rather than six special-cased ai functions. melee types (rng==0)
-- chase and contact-damage on cooldown; ranged types close until inside
-- their engage range then hold and attack, except bone archer (typ 5)
-- which kites away once the player gets inside half its range. cave bat
-- (typ 1) gets a small random per-frame jitter on top of its chase, a
-- cheap stand-in for "erratic" movement rather than a real flight pattern.
-- dx/dy/d are computed in cells, not pixels (see mrng's comment on why);
-- dx/d and dy/d stay a correctly-normalized unit direction regardless of
-- that scale, so pixel-space movement (m.x/m.y += ...*sp) is unaffected
function upd_mon(m)
  local typ,rng=m.typ,mrng[m.typ]
  local dx,dy=(px-m.x)/8,(py-m.y)/8
  local d=sqrt(dx*dx+dy*dy)
  m.cd=max(0,m.cd-1)
  if d>aggrorng then return end -- out of aggro range: idle, no chase/attack
  local sp=mspd[typ]*m.spd
  if rng>0 then
    if typ==5 and d<rng*0.5 then
      if d>0 then m.x-=dx/d*sp m.y-=dy/d*sp end
    elseif d>rng and d>0 then
      m.x+=dx/d*sp m.y+=dy/d*sp
    end
  elseif d>0.5 then
    m.x+=dx/d*sp m.y+=dy/d*sp
  end
  if typ==1 then m.x+=rnd(1)-0.5 end
  local inrange=rng>0 and d<=rng or (rng==0 and d<=0.75)
  if inrange and m.cd<=0 then
    sfx(rng>0 and 8 or 7) -- ranged launch or melee thump -- readme specs
      -- this "on windup," but no phase built a separate telegraph state
      -- for monster ai, so it plays at the moment the attack lands instead
    dmg_player(mdmg[typ])
    m.cd=30
  end
end

-- weapon swing (x, tapped): hits the first monster found within melee
-- range of the tile the player's facing (typically the only one there).
-- one hit per press since btnp already edge-detects -- holding x doesn't
-- spam swings, it engages guard instead once xhold clears guardthresh
-- (see dmg_player). moved here from o-tapped after a real bug found live-
-- playtesting this session: o held (mine, btn) and o tapped (attack,
-- btnp) fired on the identical first frame of any press, so mining a
-- block and swinging at a monster could both happen from one input.
-- mine now lives on o alone (still hold-only; a mineable block can never
-- share a cell with a chest, so o's hold-vs-tap split there was never
-- actually ambiguous) and attack+guard live on x alone -- each button is
-- one tool, per design.md's revised control table. a kill drops one unit
-- of that type's material into mat[16+typ] (ids
-- 17-22, distinct from block ids 1-16 in the same flat table -- bat wing,
-- crawler shell, slug gland, wraith essence, old bone, warden core, in
-- readme's monster-table order)
-- the point one cell ahead of the player, in their current facing --
-- shared by try_attack/open_chest, both of which hit-test against it
function facing_pt()
  return px+4+fx*8,py+4+fy*8
end

function try_attack()
  if wtier<1 then return end -- no weapon equipped (see craft()'s note on why this can happen)
  atkt=6 -- weapon-swing overlay flash, whether or not this swing connects
  sfx(5) -- swing whoosh, every attempt, connects or not
  local hx,hy=facing_pt()
  for m in all(mon) do
    local ddx,ddy=m.x+4-hx,m.y+4-hy
    -- abs() pre-filter rejects far monsters before squaring, not just for
    -- speed: squaring an unfiltered ddx/ddy would overflow pico-8's
    -- fixed-point range for anything more than ~181px away (see mrng's
    -- comment), silently corrupting the comparison instead of erroring
    if abs(ddx)<8 and abs(ddy)<8 and ddx*ddx+ddy*ddy<64 then
      sfx(1) -- monster hit taken
      m.hp-=wpow[wtier]
      if m.hp<=0 then
        local id=16+m.typ
        mat[id]=min(99,(mat[id] or 0)+1)
        sfx(10) -- material pickup
        del(mon,m)
      end
      return
    end
  end
end

-- chests: world objects, not blocks, placed on random floor cells at
-- _init() time like gen_monsters() but with no distance-tier bias --
-- readme only calls for a "modest spawn rate," not a difficulty curve.
-- opening one sets its own `opened` flag rather than deleting it from
-- the list -- unlike mined blocks/killed monsters, an opened chest stays
-- on the map (see the chest-feedback discussion), drawn via g6_chest_open
-- (slot 48) forever after, so it needs per-chest state to persist
function gen_chests()
  chest={}
  for i=1,8 do
    local cx,cy=flr(rnd(w)),flr(rnd(h))
    for t=1,20 do
      if mget(cx,cy)==0 then break end
      cx,cy=flr(rnd(w)),flr(rnd(h))
    end
    add(chest,{x=cx*8,y=cy*8,opened=false})
  end
end

-- only the 14 non-hazard block ids are valid chest loot (13/14, lava/
-- water, aren't a "material" anyone could carry)
lootmat={1,2,3,4,5,6,7,8,9,10,11,12,15,16}

-- short names for the loot popup (gs==5); block id order matches lootmat/
-- bcol/blocktier throughout, so matlab[id] works directly with no remap.
-- ids 13/14 (lava/water) are never actually rolled by loot() below, but
-- are still included so matlab[id] stays a direct, uniform lookup
matlab={"loose dirt","clay","copper ore","rubble","packed stone","iron ore",
  "mossy rock","flint","dense rock","gold ore","crystal ore","ancient stone",
  "lava","deep water","treasure vein","glowstone"}

-- weighted toward materials, occasionally a potion, rarely the book --
-- readme's "a chest that would roll a second book rolls something else
-- instead" falls out for free here: if book's already true the r<10
-- branch's guard fails and control drops through to the r<30 potion
-- branch (r<10 implies r<30), no separate re-roll needed. lootkind (1-3)
-- + lootid record what happened for draw_lootpopup() (gs==5) to show --
-- materials are granted immediately here, same as before; only the
-- popup's reveal is delayed by chopent's countdown, not the actual loot
function loot()
  local r=rnd(100)
  if r<10 and not book then
    book=true
    lootkind=3
    sfx(12) -- book find
  elseif r<30 then
    inv[8]=min(99,inv[8]+1)
    lootkind=2
    sfx(10) -- no dedicated "potion found" event in readme's sound table;
      -- reuses material pickup rather than leaving this branch silent
  else
    local id=lootmat[1+flr(rnd(14))]
    mat[id]=min(99,(mat[id] or 0)+1)
    lootkind=1
    lootid=id
    sfx(10) -- material pickup
    pushrecent(id)
  end
end

-- interact (o, tapped, facing an unopened chest): loot is granted
-- instantly (per readme's "instant, no timed search"), but the reveal is
-- staged -- chopent counts down the closed->open sprite swap (see
-- draw_chests below), then _update() flips to gs==5 for the popup once
-- it hits 0. shares try_attack's facing_pt()/abs()-prefilter targeting
-- pattern for the same overflow-safety reason (see try_attack's comment)
function open_chest()
  local hx,hy=facing_pt()
  for c in all(chest) do
    if not c.opened then
      local ddx,ddy=c.x+4-hx,c.y+4-hy
      if abs(ddx)<8 and abs(ddy)<8 and ddx*ddx+ddy*ddy<64 then
        sfx(11) -- chest open (creak+flourish), same instant as loot()'s
          -- own sfx call below -- loot is granted instantly per readme,
          -- only the visual reveal is staged by chopent, so both sounds
          -- land together rather than one waiting for the other
        c.opened=true
        chopenc,chopent=c,12
        loot()
        return true
      end
    end
  end
  return false
end

-- o-tap: open a chest if one's faced. used to also fall back to
-- try_attack() here (attack lived on o-tapped originally) -- that's gone
-- now that attack moved to x, so this is just open_chest() directly, no
-- wrapper needed

-- help overlay: full-screen, paused, matching game 2's help-screen
-- precedent (bezel border, distinct text colour) per design.md. state
-- 3 (gs==3), entered via goto_state(3) from either playing or inventory
-- (design.md's state table) and dismissed with return_state(), which is
-- exactly lib/state.lua's "resume whichever state opened this overlay"
-- case -- phase 6 built this as a standalone help_on boolean (game 2's
-- simpler single-caller pattern) since gs didn't exist as a real state
-- machine yet; phase 7 folds it into gs now that it does.
-- monster-drop reference only lists bat wing/wraith essence/warden core:
-- readme's recipe table has no crafting use for crawler shell/slug
-- gland/old bone, but they're not dead weight -- design.md's scoring
-- formula counts materials_collected regardless of recipe use, so they
-- still pay off as score. leaving the other three off a screen billed as
-- "genuinely useful" (readme) rather than padding it with entries that'd
-- send the player looking for a recipe that doesn't exist
function draw_help()
  cls(0)
  rect(2,2,125,125,6)
  local c=11
  print("help",6,6,c)
  print("arrows move",6,16,c)
  print("o: mine/open chest",6,24,c)
  print("x: tap attack,hold guard",6,32,c)
  print("o+x: inventory",6,40,c)
  print("tool tier mines matching",6,52,c)
  print("block tier or lower",6,60,c)
  print("runic pick(t4) mines any",6,68,c)
  print("bat wing -> basic blade",6,80,c)
  print("wraith essence -> mid blade",6,88,c)
  print("warden core ->",6,96,c)
  print("  adv/runic blade",6,104,c)
  if help_t<=0 then
    print("press any button to close",6,116,c)
  end
end

-- inv[1-8]: general item-type slots, readme's items-table order (basic/
-- mid/advanced pick, basic/mid/advanced blade, lantern, health potion),
-- each capped at 99. tool/wtier (equip slots) are separate from owning a
-- slot count -- equip_tool/equip_weapon below only ever set them to a
-- tier the player actually owns, so "equipped" always implies "owned"
coins=0
maxhp=20 -- doubled from design.md's first-pass 10 -- playtest feedback that
  -- the starting pool felt too thin against monster/hazard damage

-- flat recipe lookup, readme's crafting-table order. each ingredient is
-- {id,qty}: id 1-22 reads/writes mat[] (16 block ids + 6 monster-drop
-- ids, same table phases 2/4 already write into), id 101-108 reads/
-- writes inv[id-100] -- lets "1 basic pick" be consumed as an ingredient
-- the same way "3 copper ore" is, one lookup mechanism instead of two.
-- out 1-8 is a general inv[] slot; out 9/10 are runic pick/blade, which
-- don't get a slot at all (see craft())
recipe={
  {out=1,ing={{3,3}}},
  {out=2,ing={{6,3},{101,1}}},
  {out=3,ing={{10,3},{102,1}}},
  {out=4,ing={{3,2},{17,1}}},
  {out=5,ing={{6,2},{20,1}}},
  {out=6,ing={{10,2},{11,1},{22,1}}},
  {out=9,ing={{12,3},{103,1}}},
  {out=10,ing={{12,2},{22,1},{106,1}}},
  {out=7,ing={{16,2}}},
  {out=8,ing={{7,2}}},
}

function getqty(id)
  if id>100 then return inv[id-100] or 0 end
  return mat[id] or 0
end
function useqty(id,n)
  if id>100 then inv[id-100]-=n
  else mat[id]=(mat[id] or 0)-n end
end

function can_craft(ri)
  for i in all(recipe[ri].ing) do
    if getqty(i[1])<i[2] then return false end
  end
  return true
end

-- crafts recipe index ri if affordable; consumes ingredients, then either
-- produces one unit into the matching general slot, or -- runic pick/
-- blade only -- auto-equips straight into tool/wtier per readme (rp/rb
-- track "ever crafted" so equip_tool/equip_weapon can offer tier 4 again
-- later even though it has no owned-count slot to check).
-- an upgrade recipe (mid/advanced pick or blade) consumes the prior tier
-- as an ingredient; if that happened to be the currently *equipped* one,
-- its owned count just dropped to 0 while tool/wtier still names that
-- tier -- readme only auto-equips runic, not ordinary upgrades, so the
-- fix isn't to auto-equip the new item, it's to clear the now-stale
-- equip slot back to "nothing equipped" (0) rather than leave it
-- pointing at a tier the player no longer owns. try_attack already
-- guards wtier==0; try_mine's tool<tier resistance check does too, for
-- free, since 0<tier is always true
function craft(ri)
  if not can_craft(ri) then return false end
  sfx(13) -- crafting success
  for i in all(recipe[ri].ing) do useqty(i[1],i[2]) end
  local out=recipe[ri].out
  if out==9 then tool,rp=4,true
  elseif out==10 then wtier,rb=4,true
  else inv[out]=min(99,inv[out]+1) end
  if tool>=1 and tool<=3 and inv[tool]<=0 then tool=0 end
  if wtier>=1 and wtier<=3 and inv[wtier+3]<=0 then wtier=0 end
  return true
end

function equip_tool(t)
  if (t<=3 and inv[t]>0) or (t==4 and rp) then tool=t end
end
function equip_weapon(t)
  if (t<=3 and inv[t+3]>0) or (t==4 and rb) then wtier=t end
end

function add_coins(n)
  coins=min(255,coins+n)
  sfx(9) -- coin pickup
end

-- records a block-material pickup for the hud's recency feed, newest
-- first, capped at 4 distinct ids -- del() first so re-picking the same
-- material moves it to front instead of duplicating, since 4 copies of
-- "copper" is less useful to see than 4 different recent materials
function pushrecent(id)
  del(recentmat,id)
  add(recentmat,id,1)
  if #recentmat>4 then deli(recentmat,5) end
end

-- only spends the potion if it'd actually help, so it can't be wasted at
-- full hp; heals to max rather than a partial amount -- design.md doesn't
-- pin a heal amount, this is the simplest first-pass choice, not locked
function use_potion()
  if inv[8]>0 and hp<maxhp then
    inv[8]-=1
    hp=maxhp
    sfx(14) -- health potion use
  end
end

-- inventory screen (gs==2). isel (1-18) is one cursor over a single
-- combined list: 1-8 are the general item slots (readme's order), 9-18
-- are recipe[]'s 10 entries in the same order -- one selection+one
-- action button covers both equip/use and craft, instead of two cursors
-- or a mode toggle. islab/rlab are display-only short labels; runic
-- pick/blade have no manual-equip entry at all (see rlab's comment) and
-- lantern has no action (see draw_inv()'s comment) -- both intentional
-- scope cuts, not missing features
islab={"pick1","pick2","pick3","blade1","blade2","blade3","lantern","potion"}
rlab={"pick1","pick2","pick3","blade1","blade2","blade3",
  "runic pick","runic blade","lantern","potion"}

-- o (tapped) on the selected entry: items 1-3 equip that pick tier,
-- 4-6 equip that blade tier, 7 (lantern) is display-only -- no
-- visibility/fog system exists yet for it to affect (a real gap in the
-- design, not a phase-7 scope cut -- see plan.md), 8 uses a potion;
-- recipes (9-18) craft. runic pick/blade have no manual-equip entry:
-- they auto-equip the instant they're crafted (craft()), and reverting
-- to a lower tier on purpose to then manually reselect runic is obscure
-- enough to not need ui for it in a first pass
function inv_action()
  if isel<=3 then equip_tool(isel)
  elseif isel<=6 then equip_weapon(isel-3)
  elseif isel==8 then use_potion()
  elseif isel>8 then craft(isel-8)
  end
end

function draw_inv()
  cls(0)
  for i=1,8 do
    local y=2+(i-1)*6
    local eq=(i<=3 and tool==i) or (i>=4 and i<=6 and wtier==i-3)
    spr(31+i,2,y-1) -- islab's order matches sprite slots 32-39 exactly
    print((isel==i and ">" or " ")..islab[i].." x"..inv[i],11,y,eq and 11 or 7)
  end
  for i=1,10 do
    local y=2+(7+i)*6
    print((isel==8+i and ">" or " ")..rlab[i],2,y,can_craft(i) and 11 or 5)
  end
  print("$"..coins,2,112,10)
  if book then print("x:help",90,112,11) end
  print("o:equip/use/craft o+x:close",2,120,6)
end

-- world/player/run reset, split out of _init() so title->playing (and
-- end->title->playing again) can re-roll a fresh run without restarting
-- the cart. _init() itself just boots to the title state (gs==0) and
-- doesn't call this -- generating a world nobody's pressed start to see
-- yet would be wasted work every time the cart loads
function new_game()
  gen_world()
  gen_monsters()
  gen_chests()
  px,py=spx*8,spy*8
  fx,fy=0,1
  moving,walkt,atkt=false,0,0 -- walk-cycle/attack-swing animation state (phase 8)
  hflash=0 -- hit-flash timer, set by hpdmg()
  chopent,chopenc=0,nil -- chest open-animation timer + which chest is animating
  lootkind,lootid=0,0 -- what the current loot popup (gs==5) shows, set by loot()
  lootpopt=0 -- grace period before the loot popup can be dismissed, set to 30 on entry
  tool=1 -- equipped tool tier; player starts owning (see inv below) and wearing tier 1
  wtier=1 -- equipped weapon tier; same
  rp,rb=false,false -- runic pick/blade ever crafted (see craft())
  inv={1,0,0,1,0,0,0,0} -- start owning 1 basic pick + 1 basic blade,
    -- matching tool/wtier=1 above -- without this the tier-1 crafting
    -- recipes (which need copper ore, a tier-1-resistance block) would
    -- be uncraftable from a cold start with nothing equipped to mine it
  hp=maxhp -- start full, tracks maxhp rather than a separate literal
  xhold=0 -- frames x has been continuously held; see try_attack/dmg_player
  mat={} -- material counts by id: 1-16 block drops (phase 2), 17-22 monster drops
  recentmat={} -- last 4 distinct block-material ids gained, newest first;
    -- see pushrecent(), drawn on the hud. monster drops (17-22) have no
    -- icon sprite of their own, so this feed is block materials only
  book=false
  lavat=0
  rtick=0 -- frames spent facing a too-weak-tool block, for block_resist's rate limit
  coins=0
  matcount=0 -- scoring's materials_collected term; distinct from summing
    -- mat[]'s current counts, since crafting consumes those but a
    -- material once collected should still count toward score
  maxdist=0 -- scoring's distance_from_spawn_reached term; furthest the
    -- player ever got (cells), not just where the run happened to end
  isel=1 -- inventory screen cursor
  camx=mid(0,px+4-64,w*8-128)
  camy=mid(0,py+4-64,h*8-128)
end

function _init()
  gs,gsret=0,0
  combot=0 -- frames o+x have been held together; see _update()'s combo check
  combolock=false -- true right after the combo fires until a button is
    -- released, so a sustained hold can't retrigger it 10 frames later
    -- (real bug found live: opening inventory then not releasing fast
    -- enough re-counted to 10 and closed it right back, reading as "the
    -- inventory screen disappears immediately")
end

function _update()
  if gs==0 then -- title
    if any_btnp() then new_game() gs=1 end
    return
  end
  if gs==3 then -- help; entered via goto_state(3) from playing or inventory
    if help_t>0 then help_t-=1
    elseif any_btnp() then return_state() end
    return
  end
  if gs==5 then -- chest loot popup; drawn over the frozen game view, not
    -- a full screen replacement (see draw_lootpopup()) -- always entered
    -- from playing (chopent hitting 0) so it always returns straight there.
    -- lootpopt is a short grace period (same pattern as help's help_t)
    -- before any_btnp can dismiss it -- playtest feedback that it vanished
    -- almost instantly, since the o-tap that opened the chest (or a
    -- residual keypress right after) could immediately count as the
    -- dismiss input on the very next frame
    if lootpopt>0 then lootpopt-=1
    elseif any_btnp() then gs=1 end
    return
  end
  if gs==4 then -- end
    if any_btnp() then gs=0 end
    return
  end
  -- o+x toggles inventory, checked before either state's own input
  -- handling so it always takes priority. requires both held together
  -- for combot frames (not just btnp on either edge): mining (o, held)
  -- and attack (x, tapped) are both live during playing, so a quick
  -- mine-then-attack could otherwise false-trigger an edge-based combo
  -- check the instant x went down while o was already held. a short
  -- sustained-hold requirement is cheap insurance against that overlap.
  -- combolock gates re-counting once the hold has already fired once --
  -- without it, a hold that outlasts the 10-frame window just keeps
  -- counting past 10, hits it again ~10 frames later, and toggles right
  -- back (found live: inventory opened then closed itself almost
  -- immediately, since letting go of both buttons the instant it opens
  -- isn't realistic). only a release re-arms it.
  if btn(4) and btn(5) then
    if not combolock then
      combot+=1
      if combot==10 then
        if gs==1 then gs,isel=2,1 elseif gs==2 then gs=1 end
        combot,combolock=0,true
        return
      end
    end
  else
    combot,combolock=0,false
  end
  if gs==2 then -- inventory
    if btnp(2) then isel=max(1,isel-1) end
    if btnp(3) then isel=min(18,isel+1) end
    if btnp(4) then inv_action() end
    if btnp(5) and book then help_t=90 goto_state(3) end
    return
  end
  -- gs==1 (playing) from here down -- every other state already
  -- returned above
  local dx,dy=0,0
  if btn(0) then dx=-1 end
  if btn(1) then dx=1 end
  if btn(2) then dy=-1 end
  if btn(3) then dy=1 end
  moving=dx~=0 or dy~=0
  if moving then
    fx,fy=dx,dy -- facing persists as last movement direction (readme's player section)
    try_move(dx,dy)
    walkt+=1 -- walk-cycle frame timer, only advances while actually moving
  end
  -- camera: centred on player, clamped both axes to the world bounds
  -- (generalizes games 2/5's one-axis mid() clamp to two, see 6/plan.md phase 0)
  camx=mid(0,px+4-64,w*8-128)
  camy=mid(0,py+4-64,h*8-128)

  -- mine: hold o (btn(4)) while facing a block (see design.md's control table)
  local cx,cy=cell_xy(px+4,py+4)
  if btn(4) then
    try_mine(cx+fx,cy+fy)
  else
    mcx=nil
  end

  -- lava: contact damage, ticked (not per-frame) while standing on it;
  -- not mined (blocktier returns nil for id 13), just a passable hazard.
  -- goes through hpdmg() directly, not dmg_player(), so guard can't
  -- cheese terrain damage (see dmg_player's comment)
  if mget(cx,cy)==13 then
    lavat+=1
    if lavat%15==0 then hpdmg(1) end
  else
    lavat=0
  end

  -- o tapped = open a chest if one's faced (mining, above, is o held).
  -- x tapped = attack now (fires immediately, btnp, every press); x held
  -- past guardthresh frames = guard (dmg_player checks xhold directly,
  -- no separate trigger needed). xhold counts continuous-hold frames,
  -- reset the instant x is released -- attack always fires on the press
  -- edge regardless of how long the hold that follows turns out to be,
  -- so a quick tap and the start of a long guard-hold look identical
  -- until guardthresh actually passes; nothing double-fires because
  -- guard isn't a second trigger, it's dmg_player reading xhold's value
  if btnp(4) then open_chest() end
  if btnp(5) then try_attack() end
  if btn(5) then xhold+=1 else xhold=0 end
  atkt=max(0,atkt-1) -- weapon-swing overlay timer, set by try_attack()
  hflash=max(0,hflash-1) -- hit-flash timer, set by hpdmg()
  -- chest open-animation: counts down after open_chest() sets it; loot()
  -- already ran (materials are granted instantly, per readme), this is
  -- purely the closed->open sprite swap (draw_chests, below) followed by
  -- the loot popup once it reaches 0 -- see the chest-feedback discussion
  if chopent>0 then
    chopent-=1
    if chopent<=0 then gs=5 lootpopt=30 end
  end

  for m in all(mon) do upd_mon(m) end

  -- scoring's distance_from_spawn_reached: tracked live as a running max,
  -- not computed once at death, so it reflects the furthest point reached
  -- during the run rather than just wherever the player happened to die.
  -- cell units (not pixels), matching every other distance calc in this
  -- cart, for the same fixed-point-overflow reason (see mrng's comment)
  local dcx,dcy=cell_xy(px+4,py+4)
  local ddx,ddy=dcx-spx,dcy-spy
  local d=sqrt(ddx*ddx+ddy*ddy)
  if d>maxdist then maxdist=d end
end

function draw_end()
  cls(0)
  print("you died",44,20,8)
  print("coins: "..coins,30,50,7)
  print("distance: "..flr(maxdist),22,58,7)
  print("score: "..flr(maxdist+coins+matcount),30,66,7) -- design.md's
    -- score formula, k=j=1 (first-pass weights, not tuned)
  if blink(2) then print("press any button",26,100,7) end
end

-- lit radius (cells) for this frame: base, extended by an owned lantern
-- (readme: "equip or hold" -- treated as passive-while-owned, since
-- lantern has no dedicated equip slot and phase 7 left it display-only
-- in the inventory screen specifically because fog didn't exist yet to
-- give it a job) and/or a nearby glowstone. no stacking (design.md), so
-- each source is a separate max() rather than an additive bonus; breaks
-- out of the glow scan on the first hit since a second nearby glowstone
-- can't raise the radius any further
function visr()
  local r=baser
  if inv[7]>0 then r=max(r,lanternr) end
  local pcx,pcy=cell_xy(px+4,py+4)
  for g in all(glow) do
    if mget(g[1],g[2])==16 then
      local dx,dy=g[1]-pcx,g[2]-pcy
      if dx*dx+dy*dy<=glowr*glowr then
        r=max(r,glowr)
        break
      end
    end
  end
  return r
end

function _draw()
  if gs==0 then draw_title_card("6 DUG DUG DOWN") return end
  if gs==3 then camera(0,0) draw_help() return end -- screen-space ui,
    -- must reset the world camera first or the bezel/text draw offset by
    -- whatever camx/camy was left at
  if gs==4 then camera(0,0) draw_end() return end
  if gs==2 then camera(0,0) draw_inv() return end
  -- gs==5 (chest loot popup) deliberately does NOT return early here: it's
  -- a small modal drawn over the frozen game view (see _update()'s gs==5
  -- branch, which pauses everything), not a full-screen replacement like
  -- help/inventory/end above -- so it falls through and renders the world
  -- exactly like gs==1 does, then draw_lootpopup() layers on top at the end
  cls(0)
  camera(camx,camy)
  if hflash>0 then for i=1,15 do pal(i,8) end end -- full-screen hit-flash,
    -- reset below before the hud/popup draw so neither reads red too
  local cx0,cy0=cell_xy(camx,camy)
  local cx1,cy1=cell_xy(camx+127,camy+127)
  -- fog: litr is this frame's lit radius (cells); pcx/pcy is the player's
  -- own cell, both reused below to gate monsters/chests too. the outer 2
  -- rings of the lit area get a dithered dark overlay (see sparsec/densec
  -- below) instead of cutting straight to black, so the edge reads as
  -- fading vision rather than the world abruptly stopping -- blocks only
  -- for now (see scope note below), monsters/chests still hard-cut at litr
  local litr=visr()
  local pcx,pcy=cell_xy(px+4,py+4)
  local sparsec,densec={},{}
  for cx=cx0,cx1 do
    for cy=cy0,cy1 do
      local dx,dy=cx-pcx,cy-pcy
      local d2=dx*dx+dy*dy
      if d2<=litr*litr then
        local t=mget(cx,cy)
        if t>0 then
          local tier=blocktier(t)
          if tier and tool<tier then
            -- bedrock look: block's tier is above the equipped tool, so it
            -- can't be dented at all right now (try_mine's resistance gate).
            -- a flat dark tile reads as "not minable yet" instead of looking
            -- identical to a same-tier-or-lower block the player actually
            -- can break -- playtest feedback; recomputed live off `tool`
            -- every frame, so it clears the moment the player upgrades
            rectfill(cx*8,cy*8,cx*8+7,cy*8+7,5)
            rect(cx*8,cy*8,cx*8+7,cy*8+7,0)
          else
            spr(t,cx*8,cy*8)
          end
        end
        -- band the cell for the dither overlay passes below, outermost
        -- ring first since it also satisfies the sparse ring's own check
        if d2>(litr-1)*(litr-1) then add(densec,{cx,cy})
        elseif d2>(litr-2)*(litr-2) then add(sparsec,{cx,cy}) end
      end
    end
  end
  -- one fillp() set per band, not per cell -- pico-8's pattern state is
  -- global and meant to be set once per region, so this is 2 pattern
  -- switches total regardless of how many cells are in each band, not
  -- 2-per-cell. scope cut: blocks only, not monsters/chests -- extending
  -- this to them is straightforward (same band lists, keyed by pixel
  -- position instead of cell) but out of scope for this pass
  fillp(patsparse)
  for c in all(sparsec) do rectfill(c[1]*8,c[2]*8,c[1]*8+7,c[2]*8+7,0) end
  fillp(patdense)
  for c in all(densec) do rectfill(c[1]*8,c[2]*8,c[1]*8+7,c[2]*8+7,0) end
  fillp()
  for m in all(mon) do
    -- cell-space distance, not raw pixels -- squaring raw pixel deltas
    -- overflows pico-8's fixed-point range past ~181px on this map (see
    -- try_attack's comment); litr is small so this is cheap and safe
    local dx,dy=(m.x-px)/8,(m.y-py)/8
    if dx*dx+dy*dy<=litr*litr then spr(16+m.typ,m.x,m.y) end
  end
  -- opened chests permanently show the open sprite (48); the one
  -- currently mid-animation (chopenc) still shows closed (31) for the
  -- first half of chopent's countdown -- a simple 2-frame swap, not a
  -- persistent per-chest animation state
  for c in all(chest) do
    local dx,dy=(c.x-px)/8,(c.y-py)/8
    if dx*dx+dy*dy<=litr*litr then
      local cspr=31
      if c.opened then
        cspr=48
        if c==chopenc and chopent>6 then cspr=31 end
      end
      spr(cspr,c.x,c.y)
    end
  end
  draw_player()
  camera(0,0)
  draw_hud()
  pal() -- reset the hit-flash remap (if any) before the popup, so it's
    -- never drawn in flash colours even if hflash is still ticking down
  if gs==5 then draw_lootpopup() end
end

-- small modal over the frozen game view (see _update()'s gs==5 branch),
-- not a full cls()-and-replace screen like help/inventory/end -- readme's
-- ask was specifically "pop up... over the game screen," not hide it
function draw_lootpopup()
  rectfill(24,44,103,83,0)
  rect(24,44,103,83,7)
  local nm,ic
  if lootkind==3 then nm,ic="book",40
  elseif lootkind==2 then nm,ic="health potion",39
  else nm,ic=matlab[lootid],lootid
  end
  spr(ic,30,56)
  print("found:",42,50,7)
  print(nm,42,58,10)
  if lootpopt<=0 then
    print("press any button",28,74,6)
  end
end

-- bottom-strip hud, y=112-127 per design.md's screen layout, matching
-- game 2's convention of drawing its own opaque panel over whatever the
-- cave view left behind there rather than clipping the world render to
-- y=0-111 -- simpler than adding clip() calls for a jam-scope cart.
-- two real rows now (was one cramped row plus ~30px of unused space):
-- row 1 (y=113) is status text, row 2 (y=120) is an icon strip -- tool
-- and weapon pinned first, then recentmat's up-to-4-slot recency feed.
-- equip icons: tool slot is 31+tier for 1-3, 41 for runic (tier 4);
-- weapon slot is 34+tier for 1-3, 42 for runic -- same tier-4 fallback
-- toolpow/wpow already need, see their comments. guarded by tool>0/
-- wtier>0 now -- found live while redesigning this: craft()'s "clear a
-- now-unowned equip slot back to 0" path (see craft's own comment) makes
-- tool==0/wtier==0 a real reachable state, and 31+0/34+0 are sprite
-- slots 31/34, which aren't equip icons at all (31 is the closed-chest
-- sprite) -- the old one-row hud would've silently shown a chest icon
-- as your "equipped tool" in that state. drawing nothing is unambiguous
-- and needs no new art
function draw_hud()
  rectfill(0,112,127,127,1)
  line(0,111,127,111,6)
  print("hp:"..hp,2,113,7)
  print("$"..coins,44,113,10)
  print("o+x:inv",96,113,6) -- persistent control hint -- the combolock
    -- bug (see _update()'s comment) proved this gesture is genuinely
    -- easy to give up on discovering without one
  if tool>0 then spr(tool<4 and 31+tool or 41,2,120) end
  if wtier>0 then spr(wtier<4 and 34+wtier or 42,11,120) end
  for i=1,#recentmat do
    local id=recentmat[i]
    local x=22+(i-1)*16
    spr(id,x,120)
    print(mat[id] or 0,x+9,122,7)
  end
end

__gfx__
000000004444444444444444555555554545544415551555555545555555b55b555555555515155155555a55555555552222122288888888cccccccc55555555
000000004444444444444444555559554444554451515151555555555555555555555555551555515555aaa5555555552222222288888888c11c11c155555555
00000000444444444444444455559995444444445515551555555555b555b555515555551155555555555a555555c5551212222188888888cccccccc55555555
0000000044444444ffffffff555559554544454551515151455545555555b55555155555115551115555a555555c5c5512212222aa8aa8aacccccccca5a55555
000000004444444444444444559555554444444415551555555555555555b5555551555515155155555aaa5555c5c5c522222122aa8aa8aa1c11c11caa555555
000000004444444444444444599955554444544551515151555545555555555551551555155151555555a555555c5c552222212288888888cccccccc55aa5555
00000000444444444444444455955555544444445515551554554555bb55b5555515555511151155555555555555c55522222222888888881c11c11c555a5555
0000000044444444444444445555555544444444515151515555545455555555555155555551515555555555555555552222122288888888cccccccc55555555
5555555505000050004444000000000000dddd000600000000eeee00007777000077770000077700007770000007770000777000000777000077700004444440
555c55555550055504444440000000000d0dd0d0060000060eeeeee0077777700777777000777770077777000077777007777700007777700777770044444444
55c55c5505555550445445440bbbbbb00dddddd066600060eee00eee075775700777777000775570075577000777557007557770077777700777777044444444
555775550055550044444444bbbbbbbbd0dddd0d06000600eeeeeeee077777700777777000bbbbb00bbbbb0000bbbbb00bbbbb0000bbbbb00bbbbb0044aaaa44
5c5775c50055550044444444bbbbbbbb0dddddd006000060eeeeeeee00bbbb0000bbbb0000077777777770000007777777777000000777700777700044aaaa44
55c55c5505555550044444400bbbbbb0d0d0d0d060600006eeeeeeee007777000077770000007700007700000000770000770000000077000077000044444444
5555c5555550055504000040000000000d0d0d0d606000000eeeeee0000000000000000000000000000000000000000000000000000000000000000044444444
55555555050000500400004000000000d0d0d0d00000000000e00e00000000000000000000000000000000000000000000000000000000000000000004444440
00055000000660000007700000060000000600000007000000555000000660000022222000022000000200000000000000000000000000000000000000000000
00555500006666000077770000060000000600000007000005aaaa50000660000222222700222200000200000000000000000000000000000000000000000000
0005000000060900000709000006000000060000000700005aaaaaa5006666000222222700020c00000200000000000000000000000000000000000000000000
0004000000040000000400000006000000090000000900005aaaaaa5068888600222222700040000000c00000000000000000000000000000000000000000000
00400000004000000040000000060000000600000007000005aaaa50068888600222222700400000000200000000000000000000000000000000000000000000
04000000040000000400000004444400044444000444440000555000068888600222222704000000044444000000000000000000000000000000000000000000
40000000400000004000000000040000000400000004000000050000066666600222222740000000000400000000000000000990099000000009900000099000
00000000000000000000000000040000000400000004000000000000000000000022222000000000000400000099099009900000000009909900000000000099
00444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0a0000a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
44444444000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
04444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
00000000000000000000000000000000000400040004000400050005000500050550555000040004000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000550555000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000400040004000400050005000500050550555000040004000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000040004000400040000000045405440444044404444444444404440454054400000000000000000000000000000000000000000
00000000000000000000000000000000000000000550555044405540444044404444444444404440444055400000000000000000000000000000000000000000
00000000000000000000000000040004000400040550555044404440444044404444444444404440444044400000000000000000000000000000000000000000
00000000000000000000000000000000000000000550555045404540444044404444444444404440454045400000000000000000000000000000000000000000
00000000000000000000000000040004000400040550555044404440444044404444444444404440444044400000000000000000000000000000000000000000
00000000000000000000000000000000000000000550555044405440444044404444444444404440444054400000000000000000000000000000000000000000
00000000000000000000000000040004000400040550555054404440444044404444444444404440544044400000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000044404440444044404444444444404440444044400000000000000000000000000000000000000000
00000000000000000004000445405440000000004444444444444444555555554444444455555555454554444444444400000000000000000000000000000000
00000000000000000000000044405540055055504444444444444444555559554444444455555955444455444444444400000000000000000000000000000000
00000000000000000004000444404440055055504444444444444444555599954444444455559995444444444444444400000000000000000000000000000000
0000000000000000000000004540454005505550ffffffff4444444455555955ffffffff55555955454445454444444400000000000000000000000000000000
00000000000000000004000444404440055055504444444444444444559555554444444455955555444444444444444400000000000000000000000000000000
00000000000000000000000044405440055055504444444444444444599955554444444459995555444454454444444400000000000000000000000000000000
00000000000000000004000454404440055055504444444444444444559555554444444455955555544444444444444400000000000000000000000000000000
00000000000000000000000044404440000000004444444444444444555555554444444455555555444444444444444400000000000000000000000000000000
00000000000400044440444055505550444444444545544444444444000000000000000000000000444444445555555500000000000000000000000000000000
00000000000000004440444055505950444444444444554444444444000000000000000000000000444444445555555500000000000000000000000000000000
00000000000400044440444055509990444444444444444444444444000000000000000000000000444444445555555500000000000000000000000000000000
0000000000000000fff0fff055505950ffffffff4544454544444444000000000000000000000000ffffffffa5a5555500000000000000000000000000000000
0000000000040004444044405590555044444444444444444444444400000000000000000000000044444444aa55555500000000000000000000000000000000
000000000000000044404440599055504444444444445445444444440000000000000000000000004444444455aa555500000000000000000000000000000000
0000000000040004444044405590555044444444544444444444444400000000000000000000000044444444555a555500000000000000000000000000000000
00000000000000004440444055505550444444444444444444444444000000000000000000000000444444445555555500000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444445455444555555550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444445544555559550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444444444555599950000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffff45444545555559550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444444444559555550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444445445599955550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444454444444559555550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444444444555555550000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444545544444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444554444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444544454544404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444544544404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444445444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444455505550
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444455505950
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444455509990
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffff55505950
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444455905550
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444459905550
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444455905550
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444444444444455505550
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004545544444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444554444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004544454544404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444544544404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
00000000000000000000000000000000000000000000000000000000000000777000000000000000000000000000000000000000000000008888888845455444
00000000000000000000000000000000000000000000000000000000000007777700000000000000000000000000000000000000000000008888888844445544
00000000000000000000000000000000000000000000000000000000000007557700000000000000000000000000000000000000000000008888888844444444
0000000000000000000000000000000000000000000000000000000000000bbbbb0000000000000000000000000000000000000000000000aa8aa8aa45444545
0000000000000000000000000000000000000000000000000000000000007777700000000000000000000000000000000000000000000000aa8aa8aa44444444
00000000000000000000000000000000000000000000000000000000000000770000000000000000000000000000000000000000000000008888888844445445
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008888888854444444
00000000000000000000000000000000000000000000000000000000000000990990000000000000000000000000000000000000000000008888888844444444
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444445405440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444405540
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffff45404540
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444405440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444454404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444445405440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444405540
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffff45404540
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444405440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444454404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444444444404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555555545405440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555595544405540
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555999544404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555595545404540
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005595555544404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005999555544405440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005595555554404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005555555544404440
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050005
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000050005
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004444000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044444400000000000000000000050005
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000445445440000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444440000000000000000000050005
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000444444440000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000044444400000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000400000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000400000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000454554444444444400000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000444455444444444400000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000444444444444444400000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11717177711111777177711111111111111111111111aaa1aaa11111111111111111111111111111111111111111111116611111616111116661661161611111
11717171711711117171711111111111111111111111aa11a1a11111111111111111111111111111111111111111111161611611616116111611616161611111
117771777111117771717111111111111111111111111aa1a1a11111111111111111111111111111111111111111111161616661161111111611616161611111
11717171111711711171711111111111111111111111aaa1a1a11111111111111111111111111111111111111111111161611611616116111611616166611111
117171711111117771777111111111111111111111111a11aaa11111111111111111111111111111111111111111111166111111616111116661616116111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111551111111611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11115555111111611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111511111111611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111411111111611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11114111111111611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11141111111144444111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11411111111111411111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111411111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__sfx__
000a000024350213401f3301c31000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001465010620000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040000126400e620000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001866014650106450c62000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800000865008620000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300002d7411e720000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500003056030555305350000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800000665004630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002c24124220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0004000024450284502c4600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001e02000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500000a6311e440224502646000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000183501c3501f3502436000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500002055024550285600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000800001e54128550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c00002b06028060240600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
