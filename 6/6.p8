pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- 6: dug, dug, down. -- phase 1: world gen & camera. phase 2: mining.
-- phase 3: edge wrap. phase 4: combat & monsters. phase 5: inventory &
-- crafting. phase 6: chests & help

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

-- flat placeholder colour per block id, from design.md's palette table;
-- real 8x8 sprites replace this in phase 8
bcol={4,4,9,4,5,5,5,5,5,10,12,2,8,12,10,12}

function gen_world()
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
        mset(cx,cy,pick_block(cx,cy))
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
-- mhp/mtick track the single in-progress target; switching target (moved,
-- turned, or released) resets progress rather than persisting per-cell,
-- since only one block can ever be actively mined at once
function try_mine(tx,ty)
  local id=mget(tx,ty)
  local tier=id~=0 and blocktier(id)
  if not tier or tool<tier then mcx=nil return end
  if mcx~=tx or mcy~=ty then
    mcx,mcy,mhp,mtick=tx,ty,hpmax[tier],0
  end
  mtick+=1
  if mtick%6==0 then
    mhp-=toolpow[tool]
    if mhp<=0 then
      mset(tx,ty,0)
      mat[id]=min(99,(mat[id] or 0)+1)
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
mspd={0.8,0.35,0.25,0.9,0.4,0.5}
mrng={0,0,3.5,0,5.5,3.5} -- 0=melee(contact only), >0=ranged engage range
  -- in cells, not pixels: pico-8's fixed-point numbers overflow squaring
  -- anything past ~181 (16.16 format's ~32767 ceiling), and this map is
  -- 1024x512px, so upd_mon/try_attack's distance checks work in cell
  -- units (divide by 8) to stay well under that -- see plan.md's phase 4
  -- bug note. warden's "melee + occasional ranged" is approximated as a
  -- short ranged tier (slug's) rather than real dual-mode ai -- a scope
  -- cut, not an oversight
mcol={5,4,11,13,6,14} -- design.md's palette table
wpow={2,4,7,12} -- weapon damage per hit, indexed by equipped weapon tier
  -- (4th entry is runic blade's, same reason as toolpow's above)

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
    add(mon,{x=cx*8,y=cy*8,typ=typ,hp=mhp[typ],cd=0})
  end
end

function hpdmg(n)
  hp=max(0,hp-n)
  if hp<=0 then gs=4 end -- end screen; was a separate `dead` flag before
    -- phase 7's real state machine existed to hold this directly
end

-- parry (x, tapped) opens a short window (parryt, in frames); any monster
-- damage landing while it's still active is fully negated, per design.md
-- ("did damage land during the window," melee and ranged both route
-- through here). lava's hazard damage bypasses this and calls hpdmg()
-- directly -- parry is for monster attacks, not terrain
function dmg_player(n)
  if parryt>0 then parryt=0 return end
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
  local sp=mspd[typ]
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
  m.cd=max(0,m.cd-1)
  local inrange=rng>0 and d<=rng or (rng==0 and d<=0.75)
  if inrange and m.cd<=0 then
    dmg_player(mdmg[typ])
    m.cd=30
  end
end

-- weapon swing (o, tapped): hits the first monster found within melee
-- range of the tile the player's facing (typically the only one there).
-- one hit per press since btnp already edge-detects -- holding o doesn't
-- spam swings, and mining's hold-to-damage on the same button (try_mine)
-- only ever fires against blocks, never monsters, so the two don't cross.
-- a kill drops one unit of that type's material into mat[16+typ] (ids
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
  local hx,hy=facing_pt()
  for m in all(mon) do
    local ddx,ddy=m.x+4-hx,m.y+4-hy
    -- abs() pre-filter rejects far monsters before squaring, not just for
    -- speed: squaring an unfiltered ddx/ddy would overflow pico-8's
    -- fixed-point range for anything more than ~181px away (see mrng's
    -- comment), silently corrupting the comparison instead of erroring
    if abs(ddx)<8 and abs(ddy)<8 and ddx*ddx+ddy*ddy<64 then
      m.hp-=wpow[wtier]
      if m.hp<=0 then
        local id=16+m.typ
        mat[id]=min(99,(mat[id] or 0)+1)
        del(mon,m)
      end
      return
    end
  end
end

-- chests: world objects, not blocks, placed on random floor cells at
-- _init() time like gen_monsters() but with no distance-tier bias --
-- readme only calls for a "modest spawn rate," not a difficulty curve.
-- opening one removes it from the list (see open_chest()) rather than
-- tracking an opened flag, the same "fully consumed" treatment killed
-- monsters and mined blocks already get
function gen_chests()
  chest={}
  for i=1,8 do
    local cx,cy=flr(rnd(w)),flr(rnd(h))
    for t=1,20 do
      if mget(cx,cy)==0 then break end
      cx,cy=flr(rnd(w)),flr(rnd(h))
    end
    add(chest,{x=cx*8,y=cy*8})
  end
end

-- only the 14 non-hazard block ids are valid chest loot (13/14, lava/
-- water, aren't a "material" anyone could carry)
lootmat={1,2,3,4,5,6,7,8,9,10,11,12,15,16}

-- weighted toward materials, occasionally a potion, rarely the book --
-- readme's "a chest that would roll a second book rolls something else
-- instead" falls out for free here: if book's already true the r<10
-- branch's guard fails and control drops through to the r<30 potion
-- branch (r<10 implies r<30), no separate re-roll needed
function loot()
  local r=rnd(100)
  if r<10 and not book then
    book=true
  elseif r<30 then
    inv[8]=min(99,inv[8]+1)
  else
    local id=lootmat[1+flr(rnd(14))]
    mat[id]=min(99,(mat[id] or 0)+1)
  end
end

-- interact (o, tapped, facing a chest): instant, no timed search, per
-- readme. shares try_attack's facing_pt()/abs()-prefilter targeting
-- pattern for the same overflow-safety reason (see try_attack's comment)
function open_chest()
  local hx,hy=facing_pt()
  for c in all(chest) do
    local ddx,ddy=c.x+4-hx,c.y+4-hy
    if abs(ddx)<8 and abs(ddy)<8 and ddx*ddx+ddy*ddy<64 then
      loot()
      del(chest,c)
      return true
    end
  end
  return false
end

-- o-tap dispatch: a chest takes priority over a monster if somehow both
-- are in range at once (rare, unplaced against each other on purpose --
-- see gen_chests()); try_attack() already no-ops with nothing to hit
function do_action()
  if not open_chest() then try_attack() end
end

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
  print("o: mine/attack/open chest",6,24,c)
  print("x: parry",6,32,c)
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
maxhp=10

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
end

-- only spends the potion if it'd actually help, so it can't be wasted at
-- full hp; heals to max rather than a partial amount -- design.md doesn't
-- pin a heal amount, this is the simplest first-pass choice, not locked
function use_potion()
  if inv[8]>0 and hp<maxhp then
    inv[8]-=1
    hp=maxhp
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
    print((isel==i and ">" or " ")..islab[i].." x"..inv[i],2,y,eq and 11 or 7)
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
  tool=1 -- equipped tool tier; player starts owning (see inv below) and wearing tier 1
  wtier=1 -- equipped weapon tier; same
  rp,rb=false,false -- runic pick/blade ever crafted (see craft())
  inv={1,0,0,1,0,0,0,0} -- start owning 1 basic pick + 1 basic blade,
    -- matching tool/wtier=1 above -- without this the tier-1 crafting
    -- recipes (which need copper ore, a tier-1-resistance block) would
    -- be uncraftable from a cold start with nothing equipped to mine it
  hp=10 -- first-pass starting hp (design.md)
  parryt=0
  mat={} -- material counts by id: 1-16 block drops (phase 2), 17-22 monster drops
  book=false
  lavat=0
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
  if gs==4 then -- end
    if any_btnp() then gs=0 end
    return
  end
  -- o+x toggles inventory, checked before either state's own input
  -- handling so it always takes priority. requires both held together
  -- for combot frames (not just btnp on either edge): mining (o, held)
  -- and parry (x, tapped) are both live during playing, so a quick
  -- mine-then-parry could otherwise false-trigger an edge-based combo
  -- check the instant x went down while o was already held. a short
  -- sustained-hold requirement is cheap insurance against that overlap
  if btn(4) and btn(5) then
    combot+=1
    if combot==10 then
      if gs==1 then gs,isel=2,1 elseif gs==2 then gs=1 end
      combot=0
      return
    end
  else
    combot=0
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
  if dx~=0 or dy~=0 then
    fx,fy=dx,dy -- facing persists as last movement direction (readme's player section)
    try_move(dx,dy)
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
  -- goes through hpdmg() directly, not dmg_player(), so parry can't
  -- cheese terrain damage (see dmg_player's comment)
  if mget(cx,cy)==13 then
    lavat+=1
    if lavat%15==0 then hpdmg(1) end
  else
    lavat=0
  end

  -- o tapped = open a chest if one's faced, else weapon swing (do_action,
  -- edge-triggered, separate from o held's mining above); x tapped = open
  -- a parry window
  if btnp(4) then do_action() end
  if btnp(5) then parryt=8 end
  parryt=max(0,parryt-1)

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

function _draw()
  if gs==0 then draw_title_card("6 DUG DUG DOWN") return end
  if gs==3 then camera(0,0) draw_help() return end -- screen-space ui,
    -- must reset the world camera first or the bezel/text draw offset by
    -- whatever camx/camy was left at
  if gs==4 then camera(0,0) draw_end() return end
  if gs==2 then camera(0,0) draw_inv() return end
  cls(0)
  camera(camx,camy)
  local cx0,cy0=cell_xy(camx,camy)
  local cx1,cy1=cell_xy(camx+127,camy+127)
  for cx=cx0,cx1 do
    for cy=cy0,cy1 do
      local t=mget(cx,cy)
      if t>0 then
        rectfill(cx*8,cy*8,cx*8+7,cy*8+7,bcol[t])
      end
    end
  end
  for m in all(mon) do
    rectfill(m.x,m.y,m.x+7,m.y+7,mcol[m.typ]) -- placeholder: flat colour square, real sprites are phase 8
  end
  for c in all(chest) do
    rectfill(c.x,c.y,c.x+7,c.y+7,4) -- brown body
    rectfill(c.x+2,c.y+3,c.x+5,c.y+4,10) -- yellow latch highlight
  end
  rectfill(px,py,px+7,py+7,7) -- player placeholder: white square
  camera(0,0)
  draw_hud()
end

-- bottom-strip hud, y=112-127 per design.md's screen layout, matching
-- game 2's convention of drawing its own opaque panel over whatever the
-- cave view left behind there rather than clipping the world render to
-- y=0-111 -- simpler than adding clip() calls for a jam-scope cart.
-- tool/weapon show as bare tier numbers (t2/w1) rather than icons, same
-- placeholder treatment blocks/monsters get; real icons are phase 8
function draw_hud()
  rectfill(0,112,127,127,1)
  line(0,111,127,111,6)
  print("hp:"..hp,2,116,7)
  print("$"..coins,44,116,10)
  print("t"..tool.."/w"..wtier,80,116,7)
end
