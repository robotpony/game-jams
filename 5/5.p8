pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- 5: 5 to the top -- phase 1: level generation & player movement

-- row idx -1=ground(104) .. 0..3 = platform1..finish(80,56,32,8)
function rowy(idx)
 return 80-24*idx
end

function gen_level()
 chute_col=flr(rnd(16))
 tiles={}
 for r=0,3 do
  local row={}
  for c=0,15 do
   if c==chute_col then
    row[c]=0
   else
    row[c]=(rnd(1)<gapd) and 0 or 1
   end
  end
  tiles[r]=row
 end
 conn={}
 for p=0,3 do
  local lo=p-1
  local hi=p
  local cands={}
  for c=0,15 do
   if c!=chute_col then
    local lo_ok=(lo==-1) or tiles[lo][c]==1
    local hi_ok=tiles[hi][c]==1
    if lo_ok and hi_ok then add(cands,c) end
   end
  end
  local col
  if #cands>0 then
   col=cands[flr(rnd(#cands))+1]
  else
   col=flr(rnd(16))
   if col==chute_col then col=(col+1)%16 end
   if lo>=0 then tiles[lo][col]=1 end
   tiles[hi][col]=1
  end
  conn[p]={col=col,type=(rnd(1)<0.667) and "ladder" or "box"}
 end
 build_solids()
end

function build_solids()
 solids={}
 for c=0,15 do
  add(solids,{x=c*8,y=104,w=8,h=8})
 end
 for r=0,3 do
  for c=0,15 do
   if tiles[r][c]==1 then
    add(solids,{x=c*8,y=rowy(r),w=8,h=8})
   end
  end
 end
 for p=0,3 do
  if conn[p].type=="box" then
   local loy=(p==0) and 104 or rowy(p-1)
   add(solids,{x=conn[p].col*8,y=loy-12,w=8,h=8})
  end
 end
end

function solid_at(x,y,w,h)
 for s in all(solids) do
  if x<s.x+s.w and x+w>s.x and y<s.y+s.h and y+h>s.y then
   return s
  end
 end
 return nil
end

function try_grab_ladder()
 for p=0,3 do
  if conn[p].type=="ladder" then
   local c=conn[p].col
   local lo_y=(p==0) and 104 or rowy(p-1)
   local hi_y=rowy(p)
   if px+4>=c*8 and px+4<c*8+8 and py<=lo_y and py>=hi_y then
    if btn(2) or btn(3) then
     climbing=true
     climb_p=p
     px=c*8
     pvy=0
    end
   end
  end
 end
end

function upd_climb()
 local p=climb_p
 local lo_y=(p==0) and 104 or rowy(p-1)
 local hi_y=rowy(p)
 if btn(2) then py=py-1 end
 if btn(3) then py=py+1 end
 if py<hi_y then
  py=hi_y
  climbing=false
  ongnd=true
 elseif py>lo_y then
  py=lo_y
  climbing=false
  ongnd=true
 end
 if btnp(4) then climbing=false end
end

function upd_player()
 if climbing then
  upd_climb()
  return
 end
 if btn(0) then px=px-1.5 end
 if btn(1) then px=px+1.5 end
 px=mid(0,px,120)
 pvy=min(pvy+0.35,5)
 if ongnd and btnp(4) then
  pvy=-3.2
  ongnd=false
 end
 local ny=py+pvy
 local s=solid_at(px,ny,8,8)
 if s then
  if pvy>=0 then
   py=s.y-8
   ongnd=true
  else
   py=s.y+s.h
  end
  pvy=0
 else
  py=ny
  ongnd=false
 end
 try_grab_ladder()
end

function _init()
 gapd=0.15
 px=60
 py=96
 pvy=0
 ongnd=true
 climbing=false
 gen_level()
end

function _update()
 upd_player()
end

function draw_conn(p)
 local cn=conn[p]
 local c=cn.col
 local lo_y=(p==0) and 104 or rowy(p-1)
 local hi_y=rowy(p)
 if cn.type=="ladder" then
  for y=hi_y,lo_y-1,3 do
   line(c*8+2,y,c*8+2,y+1,9)
   line(c*8+5,y,c*8+5,y+1,9)
  end
 else
  rectfill(c*8,lo_y-12,c*8+7,lo_y-5,4)
  rect(c*8,lo_y-12,c*8+7,lo_y-5,7)
 end
end

function _draw()
 cls(0)
 rectfill(chute_col*8,0,chute_col*8+7,103,6)
 for r=0,3 do
  for c=0,15 do
   if tiles[r][c]==1 then
    rectfill(c*8,rowy(r),c*8+7,rowy(r)+7,4)
   end
  end
 end
 rectfill(0,104,127,111,4)
 for p=0,3 do
  draw_conn(p)
 end
 rectfill(px,py,px+7,py+7,8)
end
