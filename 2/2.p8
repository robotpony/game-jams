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
base_spd=0.6                          -- robot base speed, before the rooms-found ramp

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

-- one room's objects & robots: 3 floors x 2 sides, up to 2 objects and 1 robot per side
-- letter (or nil) marks this room as one of the first 10, holding one puzzle letter
function gen_room(letter)
  local room={objs={},robots={}}
  local pat=flr(rnd(4))+1
  for fl=0,2 do
    for side=0,1 do
      local sx=side==0 and 0 or 68
      local n=obj_count(pat)
      for k=1,n do
        local gap=60/(n+1)
        local ox=sx+gap*k-4
        local oy=floor_ground(fl)-7
        local kind=flr(rnd(4))+1
        add(room.objs,{fl=fl,side=side,x=ox,y=oy,kind=kind,item=1,found=false,prog=0})
      end
      if rnd(100)<robp[pat] then
        local rb={fl=fl,side=side,x=sx+10+flr(rnd(40)),y=floor_ground(fl)-7,
          pat=flr(rnd(3))+1,dir=flr(rnd(2))*2-1,t=30+flr(rnd(60)),flee=0,jumped=false,
          spd=base_spd*(0.7+rnd(0.6))}
        add(room.robots,rb)
      end
    end
  end
  if letter then
    if #room.objs==0 then
      add(room.objs,{fl=0,side=0,x=26,y=floor_ground(0)-7,kind=1,item=1,found=false,prog=0})
    end
    local idx=flr(rnd(#room.objs))+1
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

  word=words[flr(rnd(5))+1]
  rooms={}
  roomL={}
  roomR={}
  local idx=0
  for i=1,nf do
    local r=floors[i]
    if r==1 or r==3 then
      idx+=1
      rooms[idx]=gen_room(idx<=wlen and sub(word,idx,idx) or nil)
      roomL[i]=idx
    end
    if r==2 or r==3 then
      idx+=1
      rooms[idx]=gen_room(idx<=wlen and sub(word,idx,idx) or nil)
      roomR[i]=idx
    end
  end
end

-- concrete backdrop either side of the shaft: grey fill, coursed mortar lines
function draw_concrete(x0,x1)
  local h=nf*fh
  rectfill(x0,0,x1,h-1,5)
  for y=0,h-1,8 do
    line(x0,y,x1,y,0)
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
  sobj=nil
  lifty=topy
  liftdir=1
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
function update_robot(r)
  local lo,hi=r.side==0 and 4 or 72,r.side==0 and 56 or 124
  if r.pat==1 then
    r.t-=1
    if r.t<=0 then r.dir=-r.dir r.t=30+flr(rnd(60)) end
  elseif r.pat==2 then
    if r.t>0 then r.t-=1
    else
      r.x+=r.dir*r.spd*rmul()
      if r.x<=lo or r.x>=hi then r.dir=-r.dir r.t=15+flr(rnd(30)) end
    end
  else
    if r.fl==rfl and abs(px-r.x)<=6 then
      if jumping and not r.jumped then r.t=30 r.flee=20 r.jumped=true end
    else
      r.jumped=false
    end
    if r.t>0 then r.t-=1
    elseif r.flee>0 then
      r.flee-=1
      r.x=mid(lo,r.x+(px>r.x and -1 or 1)*r.spd*rmul(),hi)
    elseif r.fl==rfl then
      r.dir=px>r.x and 1 or -1
      r.x=mid(lo,r.x+r.dir*r.spd*rmul(),hi)
    end
  end
end

-- player/robot collision: 1 hp, knockback, brief invulnerability; also ticks invt down
function hit_check()
  if invt>0 then invt-=1 return end
  for r in all(cur_room.robots) do
    if r.fl==rfl and px<r.x+8 and px+8>r.x and py<r.y+8 and py+8>r.y then
      hp=max(0,hp-1)
      invt=45
      px=mid(0,px+(px<r.x and -6 or 6),120)
      return
    end
  end
end

function update_room()
  lifty+=liftspd*liftdir
  if lifty<=topy then lifty=topy liftdir=1
  elseif lifty>=boty then lifty=boty liftdir=-1 end

  for r in all(cur_room.robots) do update_robot(r) end
  hit_check()

  if jumping then
    jt+=1
    px=mid(0,px+jdir*0.8,120)
    py=jy0-jh*4*jt*(jT-jt)/(jT*jT)
    if jt>=jT then jumping=false py=jy0 end
    return
  end

  if ronlift then
    py=lifty
    local dir=0
    if btn(0) then dir=-1 elseif btn(1) then dir=1 end
    if dir!=0 and (lift_near(0) or lift_near(1) or lift_near(2)) then
      local nx=mid(0,px+dir*2,120)
      local cx=nx+4
      if cx<liftx0 or cx>liftx1 then
        ronlift=false
        rfl=nearest_floor(lifty)
        py=floor_ground(rfl)-7
      end
      px=nx
    end
    return
  end

  local fo=nil
  for o in all(cur_room.objs) do
    if not o.found and o.fl==rfl and abs(px-o.x)<=6 then fo=o break end
  end

  if btn(2) and fo then
    sobj=fo
    fo.prog+=1
    if fo.prog>=300 then
      if fo.item==2 then add(inv,fo.letter)
      else hp=min(5,hp+2) end
      fo.found=true
      sobj=nil
    end
    return
  end
  sobj=nil

  if btnp(2) then
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
  if dir!=0 then
    local nx=mid(0,px+dir*2,120)
    local cx=nx+4
    if cx>=liftx0 and cx<=liftx1 then
      if lift_near(rfl) then
        px=nx
        ronlift=true
        py=lifty
      elseif rfl<2 and invt<=0 then
        hp=max(0,hp-3)
        invt=45
        rfl+=1
        py=floor_ground(rfl)-7
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
end

function _update()
  if flash_t>0 then flash_t-=1 end

  if trans_t>0 then
    trans_t-=1
    return
  end

  if gs==0 then
    if any_btnp() then new_game() end
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
    if jt>=jT then jumping=false end
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
    jumping=true
    jt=0
    jdir=0
    if btn(0) then jdir=-1 elseif btn(1) then jdir=1 end
    return
  end

  local lo,hi=shaft_bounds()
  local wdir=0
  if btn(0) then wdir=-1 elseif btn(1) then wdir=1 end
  if wdir!=0 then
    spx=mid(lo,spx+wdir*2,hi)
    if spx<=0 and lo==0 then enter_room(roomL[cfloor],0) return end
    if spx>=120 and hi==120 then enter_room(roomR[cfloor],1) return end
  end
end

-- shared bottom-strip HUD (shaft & room screens): line 1 timer + floor level,
-- line 2 letters collected + hp (DESIGN.md's 2-line budget has no dedicated hp
-- slot; folding it onto the letters line surfaces it without adding a 3rd line)
function draw_hud()
  print("time "..flr(timer/30),2,112,7)
  local fl="floor "..cfloor.."/"..nf
  print(fl,126-4*#fl,112,7)
  print("letters "..#inv.."/"..wlen.."  hp "..hp,2,120,7)
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

-- one room's object: dark green body, letter glyph if it holds one
function draw_obj(o)
  rectfill(o.x,o.y,o.x+7,o.y+7,3)
  if o.item==2 then
    print(o.letter,o.x+2,o.y+1,10)
  end
end

function draw_room()
  cls(0)

  for fl=0,2 do
    local gy=floor_ground(fl)
    line(0,gy,liftx0-1,gy,5)
    line(liftx1+1,gy,127,gy,5)
  end

  rectfill(liftx0,lifty+5,liftx1,lifty+7,12)

  for o in all(cur_room.objs) do
    if not o.found then draw_obj(o) end
  end

  for r in all(cur_room.robots) do
    rectfill(r.x,r.y,r.x+7,r.y+7,8)
    pset(r.x+(r.dir>0 and 6 or 1),r.y+2,7)
  end

  if entry_side==0 then
    rect(124,floor_ground(2)-9,127,floor_ground(2)+1,7)
  else
    rect(0,floor_ground(2)-9,3,floor_ground(2)+1,7)
  end

  if invt<=0 or blink(10) then
    rectfill(px,py,px+7,py+7,7)
  end

  if sobj then
    local step=flr(sobj.prog/30)
    rectfill(px-2,py-14,px+20,py-2,7)
    rect(px-2,py-14,px+20,py-2,0)
    print(step.."/10",px,py-12,0)
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

function _draw()
  if gs==0 then draw_title_card("#2 MISSION") draw_overlay() return end

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
      line(0,y,carl-1,y,1)
    else
      rectfill(cl,y,carl-1,y+fh-1,1)
    end
    if r==2 or r==3 then
      rectfill(carr+1,y,127,y+fh-1,0)
      rect(124,y+2,127,y+fh-3,7)
      line(carr+1,y,127,y,1)
    else
      rectfill(carr+1,y,cr,y+fh-1,1)
    end
    line(carl,y,carr,y,1)
  end

  rectfill(carl,cy+2,carr,cy+fh-3,6)
  rect(carl,cy+2,carr,cy+fh-3,7)
  local yoff=jumping and jh*4*jt*(jT-jt)/(jT*jT) or 0
  rectfill(spx,cy+fh-10-yoff,spx+7,cy+fh-3-yoff,7)

  camera()
  draw_hud()
  draw_overlay()
end
__sfx__
0008001f1003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032100321003210032
000400001865018640166301461000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
