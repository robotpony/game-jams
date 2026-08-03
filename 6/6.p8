pico-8 cartridge // http://www.pico-8.com
version 43
__lua__
-- 6: dug, dug, down. -- phase 1: world gen & camera. phase 2: mining.
-- phase 3: edge wrap. phase 4: combat & monsters

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
toolpow={2,4,7} -- damage per mining tick, indexed by equipped tool tier

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
wpow={2,4,7} -- weapon damage per hit, indexed by equipped weapon tier

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
  if hp<=0 then dead=true end
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
function try_attack()
  local hx,hy=px+4+fx*8,py+4+fy*8
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

function _init()
  gen_world()
  gen_monsters()
  px,py=spx*8,spy*8
  fx,fy=0,1
  tool=1 -- equipped tool tier; placeholder until phase 5's real equip slot
  wtier=1 -- equipped weapon tier; same placeholder pattern as tool
  hp=10 -- first-pass starting hp (design.md)
  dead=false
  parryt=0
  mat={} -- material counts by id: 1-16 block drops (phase 2), 17-22 monster drops
  lavat=0
  camx=mid(0,px+4-64,w*8-128)
  camy=mid(0,py+4-64,h*8-128)
end

function _update()
  if dead then return end -- freeze on death; end screen is a later phase's job
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

  -- combat: o tapped = weapon swing (edge-triggered, separate from o
  -- held's mining above); x tapped = open a parry window
  if btnp(4) then try_attack() end
  if btnp(5) then parryt=8 end
  parryt=max(0,parryt-1)

  for m in all(mon) do upd_mon(m) end
end

function _draw()
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
  rectfill(px,py,px+7,py+7,7) -- player placeholder: white square
end
