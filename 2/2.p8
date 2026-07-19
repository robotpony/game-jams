pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- 2: 2 mission -- phase 2: rooms, objects & search

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

function any_btnp()
  for i=0,5 do
    if btnp(i) then return true end
  end
  return false
end

-- constants
nf=16       -- floors in the shaft
fh=24       -- px per floor (car height); taller for player headroom
espd=3      -- elevator px/frame (keeps ~8 frames/floor at the new spacing)
pfh=112     -- playfield height above the hud strip
maxcamy=nf*fh-pfh

carl=56     -- shaft/car interior, left x (narrow: 16px wide)
carr=71     -- shaft/car interior, right x
wt=4        -- wall thickness
cl=carl-wt  -- 52: wall's outer (concrete-facing) x, left side
cr=carr+wt  -- 75: wall's outer (concrete-facing) x, right side

-- room geometry: 3 floors, even thirds of the 112px playfield
fly={0,37,74}    -- y top of each room floor (1-indexed: fl+1)
flh={37,37,38}   -- height of each room floor
function floor_ground(fl) return fly[fl+1]+flh[fl+1]-1 end

-- centre lift: bounces between the top and bottom floor's stand-level
liftys={fly[1]+flh[1]-8,fly[2]+flh[2]-8,fly[3]+flh[3]-8}
topy=liftys[1]
boty=liftys[3]
liftspd=1
liftt=8     -- lift-near tolerance, wide enough to actually board/cross before jump exists (phase 3)
liftx0=58   -- centre lift shaft: blank/fall-through gap and platform, shared width (12px, matches the platform)
liftx1=69
fallspd=3   -- vertical speed while falling through the gap (see the "falling" state)

-- which floor's band a continuous fall y has reached, for landing on a lower
-- floor after clearing the gap column sideways mid-fall
function fall_floor(y)
  if y>=fly[3] then return 2
  elseif y>=fly[2] then return 1
  else return 0 end
end
function lift_near(fl) return abs(lifty-liftys[fl+1])<=liftt end
function nearest_floor(y)
  local best,bd=0,abs(y-liftys[1])
  for fl=1,2 do
    local d=abs(y-liftys[fl+1])
    if d<bd then bd=d best=fl end
  end
  return best
end

-- secret word & room object density
words={"impossible","infiltrate","demolition","electrical","mechanical"}
wlen=#words[1] -- all words are the same length; ties room/letter counts to real data, not a magic number
objp={{60,90},{40,75},{20,60},{5,35}} -- per pattern: thresholds for 0/1/2 objects
robp={20,35,55,75}                    -- per pattern: % chance a floor side gets a robot
base_spd=0.3                          -- robot base speed, before the rooms-found ramp (halved, was too fast)

function obj_count(pat)
  local r=flr(rnd(100))
  if r<objp[pat][1] then return 0
  elseif r<objp[pat][2] then return 1
  else return 2 end
end

-- jump: fixed parabolic arc, higher/slower than a hop, clears an 8px robot
-- or lift gap with margin (~19px horizontal over jT frames)
jT=24
jh=18

-- player sprite: 0=stand, 1-4/5-8=run right/left, 9-12/13-16=jump right/left
-- (launch/tuck/extend/land), 17-18=search reach loop
function pspr()
  if jumping then
    return (jdir<0 and 13 or 9)+min(3,flr(jt/(jT/4)))
  end
  if sobj then
    return 17+flr(sobj.prog/15)%2
  end
  if pft>0 then
    return (pdir==0 and 1 or 5)+flr(pft/6)%4
  end
  return 0
end

-- footstep sfx, synced to the run cycle: pft advances every moving frame,
-- so a fixed modulus lands on roughly 2 steps per 4-frame run cycle
function step_sfx()
  if pft%12==1 then sfx(2,3) end
end

-- one room's objects & robots: 3 floors x 2 sides, up to 2 objects and 1 robot per side
-- letter (or nil) marks this room as one of the first 10, holding one puzzle letter
-- entry_side (0/1) is which corridor this room is reached from -- terminals
-- only roll on the bottom floor, on the object-side adjacent to that door
-- (entry_side==0 spawns the player at px=116, next to object side 1; ==1
-- spawns at px=4, next to side 0 -- so door_side is the opposite value)
function gen_room(letter,entry_side)
  local room={objs={},robots={}}
  local pat=flr(rnd(4))+1
  local door_side=1-entry_side
  for fl=0,2 do
    for side=0,1 do
      local sx=side==0 and 0 or 68
      local n=obj_count(pat)
      local near_door=fl==2 and side==door_side
      for k=1,n do
        local gap=60/(n+1)
        local ox=sx+gap*k-4
        local oy=floor_ground(fl)-7
        -- kind 5 (terminal) is always item 4 (help), never a letter/health/
        -- clock container; other kinds roll clock (25%) or health (75%)
        local kind=near_door and flr(rnd(5))+1 or flr(rnd(4))+1
        local variant=flr(rnd(3))+1
        local item=kind==5 and 4 or (rnd(100)<25 and 3 or 1)
        add(room.objs,{fl=fl,side=side,x=ox,y=oy,kind=kind,variant=variant,item=item,found=false,prog=0})
      end
      if rnd(100)<robp[pat] then
        local rb={fl=fl,side=side,x=sx+10+flr(rnd(40)),y=floor_ground(fl)-7,
          pat=flr(rnd(3))+1,dir=flr(rnd(2))*2-1,t=30+flr(rnd(60)),flee=0,jumped=false,
          spd=base_spd*(0.7+rnd(0.6)),skin=flr(rnd(3)),st=0}
        add(room.robots,rb)
      end
    end
  end
  if letter then
    local elig={}
    for i=1,#room.objs do
      if room.objs[i].kind~=5 then add(elig,i) end
    end
    if #elig==0 then
      add(room.objs,{fl=0,side=0,x=26,y=floor_ground(0)-7,kind=1,variant=1,item=1,found=false,prog=0})
      add(elig,#room.objs)
    end
    local idx=elig[flr(rnd(#elig))+1]
    room.objs[idx].item=2
    room.objs[idx].letter=letter
  end
  return room
end

-- floor/room generation: corridor type per floor
-- 0=neither 1=left 2=right (each 1 room) 3=both (2 independent rooms)
-- re-rolls the seed until at least 10 valid rooms exist
function gen_floors()
  local tries=0
  repeat
    lseed=flr(rnd(32767))
    srand(lseed)
    floors={}
    nrooms=0
    for i=1,nf do
      local r=flr(rnd(4))
      floors[i]=r
      if r==3 then nrooms+=2
      elseif r>0 then nrooms+=1 end
    end
    tries+=1
  until nrooms>=wlen or tries>50

  -- space valid floors apart: wherever 2 valid floors land back-to-back,
  -- blank out the second one, but only while there's still enough room-count
  -- slack above wlen to spare -- never drops nrooms below what the puzzle
  -- needs. Pre-existing runs of 2+ blanks are left alone (the "sometimes
  -- more" case); this only ever adds gaps, never removes them.
  local slack=nrooms-wlen
  for i=2,nf do
    if floors[i]~=0 and floors[i-1]~=0 then
      local rc=floors[i]==3 and 2 or 1
      if slack>=rc then
        slack-=rc
        nrooms-=rc
        floors[i]=0
      end
    end
  end

  word=words[flr(rnd(5))+1]
  rooms={}
  roomL={}
  roomR={}
  local idx=0
  for i=1,nf do
    local r=floors[i]
    if r==1 or r==3 then
      idx+=1
      rooms[idx]=gen_room(idx<=wlen and sub(word,idx,idx) or nil,0)
      roomL[i]=idx
    end
    if r==2 or r==3 then
      idx+=1
      rooms[idx]=gen_room(idx<=wlen and sub(word,idx,idx) or nil,1)
      roomR[i]=idx
    end
  end
end

-- concrete backdrop either side of the shaft: grey fill, coursed mortar
-- lines, sparse speckle texture (deterministic hash, not rnd(), so it
-- doesn't flicker frame to frame at this every-_draw call site)
function draw_concrete(x0,x1)
  local h=nf*fh
  rectfill(x0,0,x1,h-1,5)
  for y=0,h-1,8 do
    line(x0,y,x1,y,0)
  end
  for y=2,h-1,6 do
    for x=x0+1,x1-1,5 do
      local hsh=(x*7+y*13)%23
      if hsh<3 then pset(x,y,6)
      elseif hsh<5 then pset(x,y,1) end
    end
  end
end

-- shaft x-bounds the player can walk within on the current floor: the narrow
-- column normally, extended out to the screen edge on a side with an open
-- corridor (0 on the left, 120 on the right)
function shaft_bounds()
  local r=floors[cfloor]
  local lo=(r==1 or r==3) and 0 or carl
  local hi=(r==2 or r==3) and 120 or carr-7
  return lo,hi
end

-- next floor with a corridor in the given direction, scanning past "neither"
-- floors; if none remain before the shaft's physical end, stay put
function next_stop(dir)
  local i=cfloor
  repeat
    i+=dir
  until i<1 or i>nf or floors[i]~=0
  if i<1 or i>nf then return cfloor end
  return i
end

function new_game()
  gen_floors()
  cfloor=1
  cy=0
  targety=0
  moving=false
  spx=(carl+carr-7)/2
  hp=5
  inv={}
  trans_t=0
  nvisited=0
  invt=0
  jumping=false
  pdir=0
  pft=0
  found_t=0
  timer=9000
  won=false
  score=0
  flash_t=6
  gs=1
end

-- deep wall of the shaft's last valid room; only reachable from there
function enter_control()
  gs=3
  slots={}
  csel=1
  ssel=1
  trans_t=9
  sfx(1,2)
end

-- enter the room behind a shaft corridor; side: 0=left corridor, 1=right
function enter_room(idx,side)
  cur_room=rooms[idx]
  cur_idx=idx
  entry_side=side
  rfl=2
  px=side==0 and 116 or 4
  py=floor_ground(2)-7
  ronlift=false
  jumping=false
  falling=false
  fall_from=0
  sobj=nil
  lifty=topy
  liftdir=1
  liftpause=0
  if not cur_room.seen then
    cur_room.seen=true
    nvisited=min(10,nvisited+1)
  end
  gs=2
  trans_t=9
  sfx(1,2)
end

-- speed multiplier for robot movement: ramps with rooms found, capped at 10
function rmul() return 1+min(nvisited,10)/10 end

-- a robot never crosses the centre lift gap: it's confined to the 4-56/72-124
-- span on whichever side (r.side) it spawned, across all 3 movement patterns
-- robot look/move sound cycle: bleep-bloop (slot 7) on every look/turn event,
-- a periodic buzz blip (slot 8, position-gated so it repeats roughly every
-- 8px of travel rather than needing new per-robot timer state) while
-- actively moving. Both share channel 0 (otherwise unused) across every
-- robot in the room -- a jam-scope simplification, not true per-robot
-- polyphony, so only the most recently triggered robot's sound is heard
-- if two happen to overlap
-- plays the look/turn sfx, but at most once every 90 frames (~3s) per robot
-- (r.st, ticked down below) -- bug fix: a chasing robot converging on the
-- player's exact x can flip which side it's on every single frame (r.x
-- overshooting px by a fraction of a pixel each step), re-triggering the
-- direction-change branch and its sfx(7,0) call every frame too, "stuck"
-- repeating for as long as that jitter lasted. This cooldown caps how often
-- the sound can actually fire, regardless of how often the trigger does
function look_sfx(r)
  if r.st<=0 then sfx(7,0) r.st=90 end
end

function update_robot(r)
  -- bug fix: hi used to be 56 (side 0) / 124 (side 1) -- with an 8px-wide
  -- sprite that let a robot's right edge reach into the lift gap (58-69) or
  -- past the screen's right edge (127); tightened so both edges stay clear
  local lo,hi=r.side==0 and 4 or 72,r.side==0 and 50 or 119
  if r.st>0 then r.st-=1 end
  if r.pat==1 then
    r.t-=1
    if r.t<=0 then r.dir=-r.dir r.t=30+flr(rnd(60)) look_sfx(r) end
  elseif r.pat==2 then
    if r.t>0 then r.t-=1
    else
      r.x+=r.dir*r.spd*rmul()
      if flr(r.x)%8<1 then sfx(8,0) end
      if r.x<=lo or r.x>=hi then r.dir=-r.dir r.t=15+flr(rnd(30)) look_sfx(r) end
    end
  else
    if r.fl==rfl and abs(px-r.x)<=6 then
      if jumping and not r.jumped then r.t=30 r.flee=20 r.jumped=true look_sfx(r) end
    else
      r.jumped=false
    end
    if r.t>0 then r.t-=1
    elseif r.flee>0 then
      r.flee-=1
      r.x=mid(lo,r.x+(px>r.x and -1 or 1)*r.spd*rmul(),hi)
      if flr(r.x)%8<1 then sfx(8,0) end
    elseif r.fl==rfl then
      -- bug fix: chase used to flip r.dir and move in the new direction the
      -- same frame, with no pause -- a robot could reverse on a dime every
      -- time the player crossed its x. now a direction change pauses it
      -- briefly (like patrol already did at its turn points) instead of
      -- moving that frame
      local newdir=px>r.x and 1 or -1
      if newdir~=r.dir then
        r.dir=newdir
        r.t=10
        look_sfx(r)
      else
        r.x=mid(lo,r.x+r.dir*r.spd*rmul(),hi)
        if flr(r.x)%8<1 then sfx(8,0) end
      end
    end
  end
end

-- player/robot collision: 1 hp, knockback, brief invulnerability; also ticks invt down
-- both boxes are inset 2px each side (was: robot only, inset 1px -- still
-- triggered 2-4px before the sprites actually touched, since the player's
-- own box was still the full 8x8 too; both sides tightened this pass)
function hit_check()
  if invt>0 then invt-=1 return end
  for r in all(cur_room.robots) do
    if r.fl==rfl and px<r.x+4 and px+6>r.x+2 and py<r.y+4 and py+6>r.y+2 then
      hp=max(0,hp-1)
      invt=45
      px=mid(0,px+(px<r.x and -6 or 6),120)
      return
    end
  end
end

function update_room()
  if liftpause>0 then
    liftpause-=1
  else
    lifty+=liftspd*liftdir
    if lifty<=topy then lifty=topy liftdir=1 liftpause=30
    elseif lifty>=boty then lifty=boty liftdir=-1 liftpause=30
    elseif lifty==liftys[2] then liftpause=30
    end
  end

  for r in all(cur_room.robots) do update_robot(r) end
  hit_check()

  if jumping then
    jt+=1
    px=mid(0,px+jdir*0.8,120)
    py=jy0-jh*4*jt*(jT-jt)/(jT*jT)
    local cx=px+4
    -- jt>=4 grace window: bug fix, post-Phase 6 -- a jump launched from the
    -- lift itself starts with py/cx already inside the catch tolerance (the
    -- parabola has barely moved by jt=1), so the catch fired on frame 1 of
    -- every jump off the lift and instantly re-boarded it ("sticks to it")
    if jt>=4 and cx>=liftx0 and cx<=liftx1 and abs(py-lifty)<=4 then
      jumping=false
      ronlift=true
      py=lifty
      return
    end
    if jt>=jT then
      jumping=false
      py=jy0
      sfx(4,3)
      if cx>=liftx0 and cx<=liftx1 and rfl<2 and invt<=0 then
        falling=true
        fall_from=rfl
      end
    end
    return
  end

  -- falling through the centre lift gap (floors 0-1 only; the bottom floor
  -- is solid ground, see fall_from's trigger sites): a real descent, not an
  -- instant fail. drifting sideways out of the gap column lands safely on
  -- whichever floor the fall has reached by then; catching the lift at its
  -- current y also lands safely. only reaching the bottom floor's ground
  -- while still falling costs hp, scaled by floors fallen (fall_from==0:
  -- fell past 2 floors, -2hp; fall_from==1: fell past 1 floor, -1hp) --
  -- landing there in place, not resetting to the entry door
  if falling then
    py+=fallspd
    local dir=0
    if btn(0) then dir=-1 elseif btn(1) then dir=1 end
    if dir!=0 then
      pdir=dir<0 and 1 or 0
      px=mid(0,px+dir*2,120)
    end
    local cx=px+4
    if abs(py-lifty)<=4 then
      falling=false
      ronlift=true
      py=lifty
      return
    end
    if cx<liftx0 or cx>liftx1 then
      falling=false
      rfl=fall_floor(py)
      py=floor_ground(rfl)-7
      return
    end
    if py>=floor_ground(2) then
      falling=false
      hp=max(0,hp-(fall_from==0 and 2 or 1))
      invt=45
      rfl=2
      py=floor_ground(2)-7
    end
    return
  end

  -- riding the lift behaves like standing on any floor/corridor: free
  -- left/right movement (no longer gated on the lift being paused at a
  -- floor stop -- bug fix, post-Phase 6: that gate made it impossible to
  -- move at all while the lift was mid-transit), walking off either edge
  -- lands on the nearest floor, and a jump can launch normally from it
  -- (catching the lift again mid-arc via the jumping block above, or
  -- missing it and falling/landing per the usual jump-landing logic)
  if ronlift then
    py=lifty
    local dir=0
    if btn(0) then dir=-1 elseif btn(1) then dir=1 end
    pft=dir~=0 and pft+1 or 0
    if dir!=0 then
      step_sfx()
      pdir=dir<0 and 1 or 0
      local nx=mid(0,px+dir*2,120)
      local cx=nx+4
      if cx<liftx0 or cx>liftx1 then
        ronlift=false
        rfl=nearest_floor(lifty)
        py=floor_ground(rfl)-7
      end
      px=nx
    end
    if btnp(2) then
      sfx(3,3)
      ronlift=false
      jumping=true
      jt=0
      jy0=py
      rfl=nearest_floor(jy0)
      jdir=0
      if btn(0) then jdir=-1 elseif btn(1) then jdir=1 end
    end
    return
  end

  local fo=nil
  for o in all(cur_room.objs) do
    if not o.found and o.fl==rfl and abs(px-o.x)<=6 then fo=o break end
  end

  if btn(2) and fo then
    sobj=fo
    -- terminal still counts the full 10 steps, but each one is 2x as fast
    -- (4/frame instead of 2). 4 doesn't evenly divide the 30-unit step size
    -- (unlike 2), so the tick check compares before/after step number rather
    -- than relying on an exact %30==0 hit, which a 4-wide stride can skip
    local prevprog=fo.prog
    fo.prog+=(fo.item==4 and 4 or 2)
    if flr(fo.prog/30)>flr(prevprog/30) then sfx(5,3) end
    if fo.prog>=300 then
      sfx(6,3)
      if fo.item==2 then
        add(inv,fo.letter)
        found_letter=fo.letter
        found_t=60
        fo.found=true
      elseif fo.item==3 then
        timer+=1800
        fo.found=true
      elseif fo.item==4 then
        help_on=true
        help_t=90
        fo.prog=0
      else
        hp=min(5,hp+2)
        fo.found=true
      end
      sobj=nil
    end
    return
  end
  -- releasing up (or walking away) before a terminal search completes
  -- cancels it rather than pausing it, unlike every other object -- a
  -- half-charged terminal doesn't "remember" progress between attempts
  if sobj and sobj.item==4 then sobj.prog=0 end
  sobj=nil

  if btnp(2) then
    sfx(3,3)
    jumping=true
    jt=0
    jy0=py
    jdir=0
    if btn(0) then jdir=-1 elseif btn(1) then jdir=1 end
    return
  end

  if rfl==2 then
    if cur_idx==nrooms then
      if entry_side==0 and px<=0 and btn(0) then enter_control() return end
      if entry_side==1 and px>=120 and btn(1) then enter_control() return end
    end
    if entry_side==0 and px>=120 and btn(1) then
      gs=1 spx=0 trans_t=9 sfx(1,2) return
    end
    if entry_side==1 and px<=0 and btn(0) then
      gs=1 spx=120 trans_t=9 sfx(1,2) return
    end
  end

  local dir=0
  if btn(0) then dir=-1 elseif btn(1) then dir=1 end
  pft=dir~=0 and pft+1 or 0
  if dir!=0 then
    step_sfx()
    pdir=dir<0 and 1 or 0
    local nx=mid(0,px+dir*2,120)
    local cx=nx+4
    if cx>=liftx0 and cx<=liftx1 then
      if lift_near(rfl) then
        px=nx
        ronlift=true
        py=lifty
      elseif rfl==2 then
        px=nx
      elseif invt<=0 then
        falling=true
        fall_from=rfl
        px=nx
      end
    else
      px=nx
    end
  end
end

-- control room: arrange collected letters (inv) into slots to match word
function update_control()
  if #inv>0 then
    if btnp(0) then csel=(csel-2)%#inv+1 end
    if btnp(1) then csel=csel%#inv+1 end
  end
  if btnp(2) then ssel=(ssel-2)%wlen+1 end
  if btnp(3) then ssel=ssel%wlen+1 end
  if btnp(4) then
    if slots[ssel] then
      slots[ssel]=nil
    elseif inv[csel] then
      local used=false
      for i=1,wlen do if slots[i]==csel then used=true end end
      if not used then slots[ssel]=csel end
    end
  end
  if btnp(5) then
    local guess=""
    for i=1,wlen do guess=guess..(slots[i] and inv[slots[i]] or "_") end
    if guess==word then
      score=100*#inv+2*flr(timer/30)
      won=true
      flash_t=6
      gs=4
    else
      hp=max(0,hp-1)
      slots={}
    end
  end
end

function _init()
  gs=0
  trans_t=0
  flash_t=0
  found_t=0
  help_on=false
  help_t=0
end

function _update()
  if flash_t>0 then flash_t-=1 end
  if found_t>0 then found_t-=1 end

  if help_on then
    if help_t>0 then help_t-=1
    elseif any_btnp() then help_on=false end
    return
  end

  if trans_t>0 then
    trans_t-=1
    return
  end

  if gs==0 then
    if any_btnp() then gs=5 intro_t=90 end
    return
  end

  if gs==5 then
    intro_t-=1
    if intro_t<=0 or any_btnp() then new_game() end
    return
  end

  if gs==4 then
    if any_btnp() then gs=0 end
    return
  end

  timer-=1
  if timer<=0 or hp<=0 then
    won=false
    score=0
    flash_t=6
    gs=4
    return
  end

  if gs==3 then
    update_control()
    return
  end

  if gs==2 then
    update_room()
    return
  end

  if moving then
    if cy<targety then cy=min(targety,cy+espd)
    else cy=max(targety,cy-espd) end
    if cy==targety then
      moving=false
      sfx(-1,1)
      local lo,hi=shaft_bounds()
      spx=mid(lo,spx,hi)
    end
    return
  end

  if jumping then
    jt+=1
    local lo,hi=shaft_bounds()
    spx=mid(lo,spx+jdir*0.8,hi)
    if jt>=jT then jumping=false sfx(4,3) end
    if spx<=0 and lo==0 then enter_room(roomL[cfloor],0) return end
    if spx>=120 and hi==120 then enter_room(roomR[cfloor],1) return end
    return
  end

  if spx>=carl and spx<=carr-7 then
    local dir=0
    if btn(2) then dir=-1
    elseif btn(3) then dir=1 end
    if dir!=0 then
      local nfl=next_stop(dir)
      if nfl!=cfloor then
        cfloor=nfl
        targety=(cfloor-1)*fh
        moving=true
        sfx(0,1)
      end
      return
    end
  end

  if btnp(2) then
    sfx(3,3)
    jumping=true
    jt=0
    jdir=0
    if btn(0) then jdir=-1 elseif btn(1) then jdir=1 end
    return
  end

  local lo,hi=shaft_bounds()
  local wdir=0
  if btn(0) then wdir=-1 elseif btn(1) then wdir=1 end
  pft=wdir~=0 and pft+1 or 0
  if wdir!=0 then
    step_sfx()
    pdir=wdir<0 and 1 or 0
    spx=mid(lo,spx+wdir*2,hi)
    if spx<=0 and lo==0 then enter_room(roomL[cfloor],0) return end
    if spx>=120 and hi==120 then enter_room(roomR[cfloor],1) return end
  end
end

-- shared bottom-strip HUD (shaft & room screens): line 1 timer + floor level,
-- line 2 letters collected + hp (DESIGN.md's 2-line budget has no dedicated hp
-- slot; folding it onto the letters line surfaces it without adding a 3rd line)
-- own dark-blue panel + top border, distinct from the room/shaft behind it,
-- with dim labels and brighter values so it reads as a UI layer, not a scene
function draw_hud()
  line(0,111,127,111,6)
  rectfill(0,112,127,127,1)
  print("time",2,113,6)
  print(flr(timer/30),22,113,7)
  local fl="floor "..cfloor.."/"..nf
  print(fl,126-4*#fl,113,6)
  print("letters "..#inv.."/"..wlen,2,120,6)
  print("hp "..hp,100,120,8)
end

-- screen-transition overlay: a shrinking black iris (top/bottom bars) reveals
-- the new screen over trans_t's 9 frames -- a single-phase reveal rather than
-- a true fade-out-then-fade-in crossfade, since gs already switches the instant
-- a transition starts (see enter_room/enter_control); still reads as the
-- "fades in/out" DESIGN.md asks for, at a fraction of the token cost a real
-- palette-based crossfade would need. flash_t is a separate brief white flash
-- for game start/end, decaying independently of trans_t.
function draw_overlay()
  if trans_t>0 then
    local h=flr(64*trans_t/9)
    if h>0 then
      rectfill(0,0,127,h-1,0)
      rectfill(0,127-h+1,127,127,0)
    end
  end
  if flash_t>0 then rectfill(0,0,127,127,7) end
end

-- one room's object: kind 1-4 (can/desk/vending/shelf) x variant 1-3
-- (green/brown/grey) picks a sprite from the 22-33 block; kind 5 (terminal)
-- is always sprite 43, no variants. Contents are no longer hinted here --
-- design reversal, post-Phase 6: they used to always show (BUGS.md #2.7),
-- but now stay hidden until the player actually starts searching, so
-- checking every object is the only way to know what it holds (see the
-- search progress bubble in draw_room(), which reveals the icon instead)
function draw_obj(o)
  if o.kind==5 then
    spr(43,o.x,o.y)
  else
    spr(22+(o.kind-1)*3+(o.variant-1),o.x,o.y)
  end
end

function draw_room()
  cls(0)

  for fl=0,2 do
    local gy=floor_ground(fl)
    if fl==2 then
      line(0,gy,127,gy,5)
    else
      line(0,gy,liftx0-1,gy,5)
      line(liftx1+1,gy,127,gy,5)
    end
  end

  rectfill(liftx0,lifty+5,liftx1,lifty+7,12)

  for o in all(cur_room.objs) do
    if not o.found then draw_obj(o) end
  end

  local skinbase={19,36,39}
  for r in all(cur_room.robots) do
    local base=skinbase[r.skin+1]
    spr(blink(4) and (r.dir>0 and base+2 or base+1) or base,r.x,r.y)
  end

  if entry_side==0 then
    rect(124,floor_ground(2)-9,127,floor_ground(2)+1,7)
  else
    rect(0,floor_ground(2)-9,3,floor_ground(2)+1,7)
  end

  if invt<=0 or blink(10) then
    spr(pspr(),px,py)
  end

  if sobj then
    local step=flr(sobj.prog/30)
    rectfill(px-2,py-14,px+28,py-2,7)
    rect(px-2,py-14,px+28,py-2,0)
    print(step.."/10",px,py-12,0)
    if sobj.item==2 then
      spr(35,px+20,py-13)
      print(sobj.letter,px+22,py-12,0)
    elseif sobj.item==3 then
      spr(42,px+20,py-13)
    elseif sobj.item==4 then
      spr(43,px+20,py-13)
    else
      spr(34,px+20,py-13)
    end
  end

  if found_t>0 then
    rectfill(40,48,87,64,0)
    rect(40,48,87,64,7)
    print("found:",44,54,7)
    spr(35,76,52)
    print(found_letter,78,53,0)
  end

  draw_hud()
end

-- control room: word slots (top), collected letters to pick from (below);
-- z places/clears the selected letter, x submits the arrangement
function draw_control()
  cls(0)
  print("assemble the word",26,4,7)
  for i=1,wlen do
    local bx=9+(i-1)*11
    rect(bx,20,bx+9,31,i==ssel and 10 or 7)
    print(slots[i] and inv[slots[i]] or "_",bx+3,24,7)
  end
  print("letters",46,40,7)
  for j=1,#inv do
    local bx=9+(j-1)*11
    local used=false
    for i=1,wlen do if slots[i]==j then used=true end end
    print(inv[j],bx+3,50,used and 5 or (j==csel and 10 or 7))
  end
  print("z place/clear  x submit",8,100,7)
  print("hp "..hp,2,112,7)
  print("time "..flr(timer/30),90,112,7)
end

function draw_gameover()
  cls(0)
  rectfill(0,40,127,58,won and 11 or 8)
  local msg=won and "mission complete" or "mission failed"
  print(msg,64-#msg*2,46,won and 3 or 7)
  local sc="score "..score
  print(sc,64-#sc*2,64,7)
  if blink(2) then
    local p="press any button"
    print(p,64-#p*2,100,7)
  end
end

-- terminal help screen: keys, letter/win purpose, and an object legend --
-- full-screen, freezes gameplay while shown (see help_on in _update())
function draw_help()
  cls(0)
  rect(2,2,125,125,6)
  print("help",6,8,11)
  print("arrows move, up search/jump",6,20,11)
  print("z place, x submit (ctrl rm)",6,28,11)
  print("find 10 letters, arrange",6,44,11)
  print("them at the control room",6,52,11)
  print("to win",6,60,11)
  print("search objects for health,",6,76,11)
  print("a letter, +60s time, or",6,84,11)
  print("this help (terminal)",6,92,11)
  if help_t<=0 then
    print("press any button to close",6,112,11)
  end
end

function _draw()
  if help_on then draw_help() return end

  if gs==0 then draw_title_card("#2 MISSION") draw_overlay() return end

  if gs==5 then
    cls(0)
    local t="stay a while, solve a puzzle!"
    print(t,64-2*#t,60,7)
    draw_overlay()
    return
  end

  if gs==4 then draw_gameover() draw_overlay() return end

  if gs==3 then draw_control() draw_overlay() return end

  if gs==2 then draw_room() draw_overlay() return end

  cls(0)
  local camy=mid(0,cy-44,maxcamy)
  camera(0,camy)

  draw_concrete(0,cl-1)
  draw_concrete(cr+1,127)

  for i=1,nf do
    local y=(i-1)*fh
    local r=floors[i]
    if r==1 or r==3 then
      rectfill(0,y,carl-1,y+fh-1,0)
      rect(0,y+2,3,y+fh-3,7)
      line(0,y,carl-1,y,6)
      line(0,y+fh-1,carl-1,y+fh-1,6)
      rectfill(carl-2,y,carl-1,y+fh-1,10)
    else
      rectfill(cl,y,carl-1,y+fh-1,1)
    end
    if r==2 or r==3 then
      rectfill(carr+1,y,127,y+fh-1,0)
      rect(124,y+2,127,y+fh-3,7)
      line(carr+1,y,127,y,6)
      line(carr+1,y+fh-1,127,y+fh-1,6)
      rectfill(carr+1,y,carr+2,y+fh-1,10)
    else
      rectfill(carr+1,y,cr,y+fh-1,1)
    end
    line(carl,y,carr,y,1)
  end

  rectfill(carl,cy+2,carr,cy+fh-3,6)
  rect(carl,cy+2,carr,cy+fh-3,7)
  local yoff=jumping and jh*4*jt*(jT-jt)/(jT*jT) or 0
  spr(pspr(),spx,cy+fh-10-yoff)

  camera()
  draw_hud()
  draw_overlay()
end
__gfx__
00077000000770000007700000077000000770000007700000077000000770000007700000000000000770000007700000000000000000000007700000077000
00077000000770000007700000077000000770000007700000077000000770000007700000007700007777000007700000077000007700000077770000077000
00077000000770000007700000077000000770000007700000077000000770000007700000007700077777000077700000077000007700000077777000077700
00777700007777000077770000777700007777000077770000777700007777000077770000077700077777000777770000777700007770000077777000777770
00777700007777700077770007777700007777000777770000777700007777700077770007777000007777000077700007777700000777700077770000077700
00077000000770000007700000077000000770000007700000077000000770000007700007777000000770000007000007777700000777700007700000007000
00700700007007000007700000700700000770000070070000077000007007000007700007000070000000000000700007000070070000700000000000070000
00700700070000700007000007000070007000000700007000007000070000700000070000000000000000000000070000000000000000000000000000700000
00000000070000700000000000888800008888000088880000333300004444000055550000333000004440000055500003333330044444400555555003333330
00077000000770000700007008888880088888800888888000033000000440000005500000333000004440000055500003030330040404400505055003000030
00077000000770000007700008888880087788800888778000333300004444000055550000033000000440000005500003030330040404400505055003000030
00777700077777000777770008888880088888800888888000333300004444000055550003333330044444400555555003333330044444400555555003333330
0077777000777700007777000d0000d00d0000d00d0000d000333300004444000055550003000030040000400500005003030330040404400505055003000030
0077777000077000000770000d0000d00d0000d00d0000d000333300004444000055550003000030040000400500005003030330040404400505055003000030
0700007000700700007007000d0000d00d0000d00d0000d000333300004444000055550003000030040000400500005003333330044444400555555003333330
00000000007007000070070000000000000000000000000000333300004444000055550000000000000000000000000003333330044444400555555000000000
0444444005555550000bb0000aaaaa00008888000088880000888800002222000022220000222200007770000666660000000000000000000000000000000000
0400004005000050000bb000aaaaaaa0088888800888888008888880022222200222222002222220070000700600006000000000000000000000000000000000
0400004005000050000bb000aaaaaaa00888888008aa88800888aa80022222200277222002227720700700700600006000000000000000000000000000000000
04444440055555500bbbbbb0aaaaaaa0088888800888888008888880022222200222222002222220700777700666660000000000000000000000000000000000
04000040050000500bbbbbb0aaaaaaa0080000800800008008000080020000200200002002000020700000700006600000000000000000000000000000000000
0400004005000050000bb000aaaaaaa0080000800800008008000080020000200200002002000020070000700066600000000000000000000000000000000000
0444444005555550000bb000aaaaaaa0080000800800008008000080020000200200002002000020007770000666666000000000000000000000000000000000
0000000000000000000bb0000aaaaa00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__label__
000000000000000000000000000000000000000000000000000011111111111111111111aa666666666666666666666666666666666666666666666666666666
555555555555555555555555555555555555555555555555555511110000000000000000aa000000000000000000000000000000000000000000000000000000
555555555555555565555555556555555555655555555515555511117777777777777777aa000000000000000000000000000000000000000000000000007777
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
000000000000000000000000000000000000000006000000000011117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666666666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666776666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666776666667aa000000000000000000000000000000000000000000000000007007
000000000000000000000000000000000000000000000000000011117666666776666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666667777666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666667777666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117666666776666667aa000000000000000000000000000000000000000000000000007007
555555155555555515555555555555555555555555555555555511117666667667666667aa000000000000000000000000000000000000000000000000007007
555555555555555555555555555555555555555555555555555511117777777777777777aa000000000000000000000000000000000000000000000000007777
555555555555555555555555555555555555555555555555555511110000000000000000aa000000000000000000000000000000000000000000000000000000
555555555555555555555555555555555555555555555555555511110000000000000000aa666666666666666666666666666666666666666666666666666666
00000000000000000000000000000000000000000000000000001111111111111111111111110000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
56555555555655555555565555555551555555555155555555551111000000000000000011115155555555515555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
00000000000000000000000000600000000060000000006000001111000000000000000011110000006000000000600000000010000000001000000000000000
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555556555555555655555555565555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
00000000000000000000000000000000000000000000000000001111000000000000000011110000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
51555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555655555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
666666666666666666666666666666666666666666666666666666aa111111111111111111110000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
777700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011110600000000010000000001000000000000000000000000000000
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555556555555555655555555565555555551555555555155555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011110000000000000000000000000000000000000000000000000000
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
700700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555655555555565555555555
777700000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
000000000000000000000000000000000000000000000000000000aa000000000000000011115555555555555555555555555555555555555555555555555555
666666666666666666666666666666666666666666666666666666aa000000000000000011115555555555555555555555555555555555555555555555555555
00000000000000000000000000000000000000000000000000001111111111111111111111110000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
51555555555155555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
00000060000000006000000000100000000010000000000000001111000000000000000011110000001000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555565555555556555555555655555555551111000000000000000011115655555555565555555551555555555155555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
00000000000000000000000000000000000000000000000000001111000000000000000011110000000000000000000000000000000000000000000000000000
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555556555551111000000000000000011115555555555555555655555555565555555556555555555155555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555551111000000000000000011115555555555555555555555555555555555555555555555555555
666666666666666666666666666666666666666666666666666666aa1111111111111111aa666666666666666666666666666666666666666666666666666666
000000000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000000000
777700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007777
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
700700000000000000000000000000000000000000000000000000aa0000000000000000aa000000000000000000000000000000000000000000000000007007
66666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666666
11666166616661666111117771777171111111111111111111111111111111111111111111111111111111666161111661166166611111661111616611611111
11161116116661611111111171717171111111111111111111111111111111111111111111111111111111611161116161616161611111161116111611611111
11161116116161661111117771777177711111111111111111111111111111111111111111111111111111661161116161616166111111161116111611666111
11161116116161611111117111117171711111111111111111111111111111111111111111111111111111611161116161616161611111161116111611616111
11161166616161666111117771117177711111111111111111111111111111111111111111111111111111611166616611661161611111666161116661666111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11611166616661666166616661166111116661116166116661111111111111111111111111111111111111111111111111118181888111118881111111111111
11611161111611161161116161611111116161161116116161111111111111111111111111111111111111111111111111118181818111118111111111111111
11611166111611161166116611666111116161161116116161111111111111111111111111111111111111111111111111118881888111118881111111111111
11611161111611161161116161116111116161161116116161111111111111111111111111111111111111111111111111118181811111111181111111111111
11666166611611161166616161661111116661611166616661111111111111111111111111111111111111111111111111118181811111118881111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111

__sfx__
0008001f1003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032
000400001865018640166301461000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001863014610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001025118251202412823000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400000865006620000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300002434020320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000183501c3501f3502436000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002844020430000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001073000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
