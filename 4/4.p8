pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- 4: gyri -- phase 3: enemy attack behaviour

CX,CY=64,55
SR=64
SC=0.19167
ST=0.00556
FCD=4
SSPD=4
ER={53,43,33}
EB={0.13889,0.11111,0.08333}
ESPD=0.0007
RGR=1
D1X,D1Y=64,12
D1R=10
CSPD=0.01
ND1=360
ND2=360
GD0=4
GGR=1.6
GN=6
DVSPD=3
ESSPD=3

-- lib/math.lua
-- pico-8's sin() is inverted (sin(x)==-sin(2*pi*x)) for its y-down screen
-- convention; negate the sin term so increasing a sweeps rightward. the
-- cos term is added, not subtracted, since the arc is a valley opening
-- upward (implied centre above the screen) rather than a dome.
function arc_xy(cx,cy,r,a)
  return cx-r*sin(a),cy+r*cos(a)
end

function spawn_wave()
  local n=min(24,18+2*(wv-1))
  local t1=flr(n*7/18+0.5)
  local t2=flr(n*6/18+0.5)
  local cnt={t1,t2,n-t1-t2}
  local idx=0
  for t=1,3 do
    for i=1,cnt[t] do
      local ea=-EB[t]+2*EB[t]*(i-1)/(cnt[t]-1)
      add(en,{tr=t,ea=ea,dir=1,r=0,ca=idx/n,x=D1X,y=D1Y,dv=0,mc=0,fc=rnd(90)})
      idx+=1
    end
  end
end

function _init()
  sang=0
  ft=0
  shots={}
  eshots={}
  en={}
  ET=0
  lv=5
  wv=1
  sc=0
  frz=0
  over=0
  spawn_wave()
end

function _update()
  if over==1 then return end
  if frz>0 then
    frz-=1
    if frz<=0 then
      wv+=1
      ET=0
      en={}
      eshots={}
      spawn_wave()
    end
    return
  end

  if btn(0) then sang=max(-SC,sang-ST) end
  if btn(1) then sang=min(SC,sang+ST) end
  local shx,shy=arc_xy(CX,CY,SR,sang)

  if ft>0 then ft-=1 end
  if btn(4) and ft<=0 then
    ft=FCD
    local dx,dy=arc_xy(0,0,-1,sang)
    add(shots,{x=shx,y=shy,vx=dx*SSPD,vy=dy*SSPD})
  end

  for i=#shots,1,-1 do
    local s=shots[i]
    s.x+=s.vx
    s.y+=s.vy
    if s.x<0 or s.x>127 or s.y<0 or s.y>127 then
      del(shots,s)
    end
  end

  ET+=1
  local wfc=max(20,90-5*(wv-1))
  local dch=min(0.5,0.05+0.015*(wv-1))
  local espd=ESPD*(1+0.08*(wv-1))
  for e in all(en) do
    if e.dv==1 then
      e.x+=e.dvx
      e.y+=e.dvy
      if abs(e.x-shx)<3 and abs(e.y-shy)<3 then
        lv=max(0,lv-1)
        e.dv=0
        e.ea=e.dvsg*EB[e.tr]
        e.dir=-e.dvsg
        e.r=ER[e.tr]
      elseif e.x<0 or e.x>127 or e.y<0 or e.y>127 then
        e.dv=0
        e.mc=min(7,e.mc+1)
        e.ea=e.dvsg*EB[e.tr]
        e.dir=-e.dvsg
        e.r=ER[e.tr]
      end
    else
      e.ea+=espd*e.dir
      local b=EB[e.tr]
      if e.ea>b then
        e.ea=b
        e.dir=-1
      elseif e.ea<-b then
        e.ea=-b
        e.dir=1
      end
      e.ca+=CSPD
      if ET<ND1 then
        e.x,e.y=arc_xy(D1X,D1Y,D1R,e.ca)
      elseif ET<ND1+ND2 then
        local p=(ET-ND1)/ND2
        local cx1,cy1=arc_xy(D1X,D1Y,D1R,e.ca)
        e.x=cx1+(CX-cx1)*p
        e.y=cy1+(CY-cy1)*p
      else
        if e.r<ER[e.tr] then e.r=min(ER[e.tr],e.r+RGR) end
        e.x,e.y=arc_xy(CX,CY,e.r,e.ea)
        if e.r>=ER[e.tr] then
          if e.fc>0 then e.fc-=1 end
          if e.fc<=0 and #en+#eshots<32 then
            e.fc=max(20,wfc-10*e.mc)
            local dx,dy=arc_xy(0,0,1,e.ea)
            add(eshots,{x=e.x,y=e.y,vx=dx*ESSPD,vy=dy*ESSPD})
          end
          if rnd(1)<dch/30 then
            e.dv=1
            e.dvsg=e.ea<0 and -1 or 1
            local ddx,ddy=shx-e.x,shy-e.y
            local dl=max(1,sqrt(ddx*ddx+ddy*ddy))
            local sp=DVSPD*(1+0.08*(wv-1))*min(2,1+0.15*e.mc)
            e.dvx=ddx/dl*sp
            e.dvy=ddy/dl*sp
          end
        end
      end
    end
  end

  for i=#eshots,1,-1 do
    local s=eshots[i]
    s.x+=s.vx
    s.y+=s.vy
    if abs(s.x-shx)<3 and abs(s.y-shy)<3 then
      lv=max(0,lv-1)
      del(eshots,s)
    elseif s.x<0 or s.x>127 or s.y<0 or s.y>127 then
      del(eshots,s)
    end
  end

  for i=#shots,1,-1 do
    local s=shots[i]
    for j=#en,1,-1 do
      local e=en[j]
      if abs(s.x-e.x)<3 and abs(s.y-e.y)<3 then
        sc+=50*e.tr+(e.dv==1 and 50 or 0)
        del(shots,s)
        del(en,e)
        break
      end
    end
  end

  if lv<=0 then
    over=1
  elseif #en==0 and frz<=0 then
    frz=36
  end
end

function _draw()
  cls(0)
  local d=GD0
  for i=1,GN do
    line(0,CY-d,127,CY-d,1)
    line(0,CY+d,127,CY+d,1)
    d*=GGR
  end
  line(0,120,127,120,7)
  for i=-2,2 do
    local ex,ey=arc_xy(CX,CY,200,SC*i/2)
    line(CX,CY,ex,ey,1)
  end
  circfill(CX,CY,2,0)
  for e in all(en) do
    local dx,dy=e.x-CX,e.y-CY
    local sz=mid(1,(60-sqrt(dx*dx+dy*dy))/10,3)
    circfill(e.x,e.y,sz,8)
  end
  local sx,sy=arc_xy(CX,CY,SR,sang)
  circfill(sx,sy,3,7)
  for s in all(shots) do
    pset(s.x,s.y,7)
  end
  for s in all(eshots) do
    pset(s.x,s.y,14)
  end
  print("lv "..lv.." sc "..sc.." w "..wv,2,2,7)
end
