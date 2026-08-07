-- Gyri #4 (TIC-80 upscale) -- POC Stage B: movement & waves
--
-- Stage A proved the static layout (see PLAN.md's Phase 0b Stage A);
-- this stage makes it move: ship arc movement + hold-to-fire, a
-- per-wave entrance (enemies spawn at the entry points/"planets",
-- circle briefly, then descend into formation over 5-15s), enemy
-- sweep per tier once settled (tier 4's restricted band is genuinely
-- new logic, not a port), enemy fire-back and dives, and wave
-- spawn/clear. No title screen, end screen, or wave-transition overlay
-- yet -- those are Stage C's job (PLAN.md); on 0 lives this just
-- freezes rather than showing a real end screen, and a wave clear
-- spawns the next wave's entrance immediately rather than playing the
-- zoom/iris sequence.
--
-- Ported from `4/pico-8/4.p8` where the mechanic carries over (ship
-- movement, hold-to-fire, tiered sweep, enemy fire/dive, the two-phase
-- entrance spiral), with the geometry re-derived for the new
-- centre/radii rather than the pico-8 numbers reused. Difficulty-ramp
-- constants below are placeholders in the same shape as pico-8's own
-- formulas, not yet tuned by play (see PLAN.md's Stage B checklist).
--
-- TIC-80 dialect notes vs Pico-8 (see ../../tools/tic80.md):
--   - circ() is FILLED, circb() is outline (inverted from Pico-8's
--     circ()/circfill() naming -- the easiest one to port wrong)
--   - math.sin/cos take radians (full stdlib), not Pico-8's 0-1 turns
--   - no pal() equivalent; palette is set once via poke() into VRAM's
--     palette bytes at 0x3fc0 (3 bytes/colour, RGB) -- confirmed
--     against tic_api_poke's default bits=8 (byte-addressed), not the
--     nibble-addressed poke4() the (separate) draw-time colour-mapping
--     layer uses
--   - standard Lua 5.4 stdlib, not pico-8's shorthand globals: no
--     rnd()/add()/del()/flr(), use math.random()/table.insert()/
--     table.remove()/math.floor() instead
--   - btn() bit order is up,down,left,right,a,b,x,y (confirmed against
--     this build's own tic_sys_default_mapping, not assumed from
--     pico-8's left/right/up/down/o/x order) -- left=btn(2),
--     right=btn(3), fire=btn(4)

-- palette: synthwave remap, confirmed with the user as swatches before
-- landing here (see PLAN.md Phase 0b Stage A). Index *roles* still
-- mirror Pico-8's where it mattered: 0 background, 7 ship body
-- (fixed, never re-tints), 8 ship trim (fixed, never re-tints).
PAL={
 {0x15,0x07,0x26}, {0x2c,0x12,0x50}, {0x4d,0x1a,0x7d}, {0x7b,0x1e,0x6e},
 {0xc7,0x38,0x66}, {0x4a,0x44,0x70}, {0x9a,0x93,0xc9}, {0xf2,0xea,0xff},
 {0xff,0x38,0x64}, {0xff,0x7a,0x3d}, {0xff,0xd2,0x3f}, {0x3d,0xf2,0xa0},
 {0x00,0xe5,0xff}, {0x6b,0x17,0x43}, {0xff,0x5e,0xc4}, {0xff,0xb8,0xa8},
}

function set_palette()
 for i=0,15 do
  local c=PAL[i+1]
  poke(0x3fc0+i*3+0,c[1])
  poke(0x3fc0+i*3+1,c[2])
  poke(0x3fc0+i*3+2,c[3])
 end
end

-- shared geometry -- see PLAN.md's Phase 0b Stage A numbers table.
-- Nothing here is locked; this is the proposal being visually checked.
CX,CY=120,56            -- shared centre
R_SHIP=70                -- outer lane's vertical reach -- must match LANES[1].b
SHIP_TRIM=90             -- degrees, ship's max deflection each side -- exactly 90, see LANES below
SHIP_Y=CY+R_SHIP          -- 126, ship rest position y
HUD_Y=126                 -- HUD band starts here (10px to y=136)

-- player movement lanes: up/down step between these (a discrete stack
-- of concentric arcs, not a continuous radius) -- a live play-test
-- request replacing the earlier continuous up/down radius control.
--
-- A first pass used plain circles (one radius per lane, shared trim).
-- That can't satisfy "every arc touches the horizon, with the outer
-- arc also touching the bottom and both sides" -- a circle centred at
-- (CX,CY) that reaches the bottom of the playfield straight down
-- (radius 70, touching y=126) is nowhere near wide enough to also
-- reach the screen's left/right edges (radius would need to be 120),
-- and a single shared radius can't be both at once. The fix is an
-- ellipse, not a circle: `lane_xy(a,b,deg) = (cx+a*sin(deg),
-- cy+b*cos(deg))`, horizontal semi-axis `a` and vertical semi-axis `b`
-- set independently per lane. With SHIP_TRIM at exactly 90 deg,
-- cos(90)=0 for every lane regardless of `b`, so every lane's extreme
-- deflection sits exactly on the horizon (y=CY) for free -- "touches
-- the horizon" falls out of the trim angle, not a per-lane constraint.
-- The outer lane additionally sets a=120 (half the screen width) so
-- its own extreme deflection also reaches the literal left/right
-- edges, and b=70 (unchanged from the old fixed radius) so straight
-- down still touches the bottom of the playfield (y=126). Inner lanes
-- shrink both axes together, nested inside the outer one, matching
-- "each concentric arc gets smaller, towards the horizon".
--
-- Ship (and alien, see draw_enemies) size used to be tied to which
-- lane/tier something was in; a play-test note pointed out that's the
-- wrong axis: size should track how close to the horizon something
-- actually *is* on screen, continuously, not which discrete arc it
-- happens to occupy. See size_by_y below -- LANES no longer carries
-- its own size field at all.
LANES={
 {a=120,b=70}, {a=95,b=54}, {a=70,b=39}, {a=45,b=25}, {a=22,b=12},
}
LANE_EASE=0.4 -- fraction of the remaining gap closed per frame when switching lanes -- "slide, but more like a snap"

-- enemy tiers: radius, angular band, placeholder count, colour.
-- Tiers 1-3 sweep a symmetric band centred on straight-down (deg 0).
-- Tier 4 (the new wide "wing" tier) is different on purpose: its
-- restricted band (75-88 deg, both sides, never near 0) is what keeps
-- its radius-100 sweep from landing below the ship -- see the PLAN.md
-- Phase 0b intro for the derivation (sin barely drops 75-90 deg while
-- cos does, so this keeps nearly all the horizontal reach with a much
-- smaller vertical bob than a wide-through-the-middle band would have).
-- Tiers 1-3's bands widened 50/55/60 -> 65/70/75 after the first proxy
-- render showed a visible gap between the core fan and tier 4's edge
-- columns; tier 3's 75 deg outer edge now hands off almost exactly to
-- tier 4's 75 deg inner edge instead of leaving a gap. Widening tier
-- 4's own band instead (the other fix considered) was rejected: it
-- closed the gap too, but dragged tier 4 down to nearly the ship's own
-- height band, undercutting the reason that tier has a restricted band
-- at all. See PLAN.md's Phase 0b Stage A notes for the 3-way comparison.
TIERS={
 {r=24, band=65,               n=12, c=8},  -- inner
 {r=36, band=70,               n=10, c=8},  -- middle
 {r=48, band=75,               n=9,  c=8},  -- outer
 {r=100,band_lo=75,band_hi=88, n=8,  c=14}, -- wing (new)
}

EX_L,EX_R=60,180   -- entry points ("planets")
EX_Y=12
ZOOM_X,ZOOM_Y=120,12 -- undrawn wave-transition zoom target

function arc_xy(r,deg)
 local rad=math.rad(deg)
 return CX+r*math.sin(rad), CY+r*math.cos(rad)
end

-- ellipse version of arc_xy, for the player's LANES (see that table's
-- comment) -- enemies stay on plain circles (arc_xy), only the ship
-- needs independent horizontal/vertical reach
function lane_xy(a,b,deg)
 local rad=math.rad(deg)
 return CX+a*math.sin(rad), CY+b*math.cos(rad)
end

-- size (half-size in px, or any other min/max unit) scaled by how far
-- down the screen y actually is, from the horizon (minv, distance 0)
-- to the HUD line (maxv, distance HUD_Y-HORIZON_Y). Used for the ship,
-- whose whole movement range (every LANES ellipse) already sits
-- between those two lines.
function size_by_y(y,minv,maxv)
 local t=math.max(0,math.min(1,(y-HORIZON_Y)/(HUD_Y-HORIZON_Y)))
 return minv+(maxv-minv)*t
end

-- alien size: two segments, not size_by_y's one, because an alien's y
-- range starts well above the horizon (the entry points, EX_Y=12) --
-- size_by_y would hold every alien at minimum size for that entire
-- span (t clamped to 0 above the horizon) and only start growing once
-- it crosses below y=56, reading as flat-then-sudden rather than a
-- steady approach. Segment 1 (planets to horizon) does most of the
-- growing, tiny to medium; segment 2 (horizon to the HUD line, the
-- land side, where the settled formation actually lives) only grows
-- medium to max slightly, per a play-test note asking for exactly this
-- split ("from tiny to medium" over the first stretch, "only slightly
-- larger" after the horizon).
function alien_size_by_y(y,minv,maxv)
 local mid=minv+(maxv-minv)*0.6
 if y<=HORIZON_Y then
  local t=math.max(0,math.min(1,(y-EX_Y)/(HORIZON_Y-EX_Y)))
  return minv+(mid-minv)*t
 else
  local t=math.min(1,(y-HORIZON_Y)/(HUD_Y-HORIZON_Y))
  return mid+(maxv-mid)*t
 end
end

-- pure direction (unit vector) at angle deg, same convention as
-- arc_xy but without the centre offset -- outward from the shared
-- centre. Used for shot velocity: enemy shots travel outward
-- (dir_xy(ea)), player shots travel inward (the negation).
function dir_xy(deg)
 local rad=math.rad(deg)
 return math.sin(rad), math.cos(rad)
end

-- distance from the shared centre, at angle deg (same convention as
-- arc_xy: 0=straight down), out to whichever boundary it hits first --
-- the horizontal bounds are always the screen's own edges (0/240); the
-- caller picks the y bound, 136 (literal bottom edge) here for the
-- decorative trim lines. Every LANES radius already stays clear of the
-- HUD line on its own (see LANES' comment), so this isn't needed for
-- ship movement any more, only for these visual guide rays.
function edge_dist(deg,y_bound)
 local rad=math.rad(deg)
 local dx,dy=math.sin(rad),math.cos(rad)
 local t=1/0
 if dx>0 then t=math.min(t,(240-CX)/dx)
 elseif dx<0 then t=math.min(t,(0-CX)/dx) end
 if dy>0 then t=math.min(t,(y_bound-CY)/dy)
 elseif dy<0 then t=math.min(t,(0-CY)/dy) end
 return t
end

function ray_to_edge(deg)
 local rad=math.rad(deg)
 local t=edge_dist(deg,136)
 return CX+math.sin(rad)*t, CY+math.cos(rad)*t
end

HORIZON_Y=CY -- land/sky boundary; the shared centre sits exactly on it,
             -- so the trim rays in draw_centre() already start here

function draw_sky()
 -- black sky with a subtle warm glow near the horizon, fading to plain
 -- background (idx 0) further up -- cls(0) already filled this area,
 -- so only the glow bands need drawing
 line(0,HORIZON_Y-1,240,HORIZON_Y-1,9)  -- orange, right above the horizon
 line(0,HORIZON_Y-2,240,HORIZON_Y-2,9)
 line(0,HORIZON_Y-3,240,HORIZON_Y-3,13) -- maroon, fading out
 line(0,HORIZON_Y-4,240,HORIZON_Y-4,13)
end

function draw_grid()
 -- land only (below the horizon) -- the sky above it is draw_sky()'s
 -- job now, not a mirrored copy of this same grid
 line(0,HORIZON_Y,240,HORIZON_Y,9) -- horizon line itself, brightest point
 local d,step=6,1.7
 for i=1,7 do
  line(0,CY+d,240,CY+d,1)
  d=d*step
 end
end

function draw_entry_points()
 circb(EX_L,EX_Y,3,10)
 circb(EX_R,EX_Y,3,10)
 circb(ZOOM_X,ZOOM_Y,1,6) -- undrawn in the real game; shown faint here for layout-check purposes only
end

function draw_centre()
 circ(CX,CY,2,7)
 -- trim boundary rays: used to stop at the ship's own arc radius, now
 -- run from the horizon (CX,CY) all the way to the screen edge
 local x1,y1=ray_to_edge(-SHIP_TRIM)
 local x2,y2=ray_to_edge(SHIP_TRIM)
 line(CX,CY,x1,y1,1)
 line(CX,CY,x2,y2,1)
 line(CX,CY,CX,SHIP_Y,1)
end

-- movement/combat constants -- placeholders in the same shape as
-- pico-8's own formulas (see 4/pico-8/4.p8's ESPD/wfc/dch/DVSPD), not
-- yet tuned by play; PLAN.md's Stage B difficulty-ramp item covers
-- doing that against a real running game rather than guessing here.
SHIP_STEP=2   -- deg/frame, full ±SHIP_TRIM sweep in ~1.4s at 82 deg
FIRE_CD=6     -- frames between player shots while held
SHOT_SPD=4    -- player shot speed, px/frame
ESHOT_SPD=2.5 -- enemy shot speed, px/frame (slower, more reaction time on the bigger canvas)
-- halved from an initial 0.4 after a live play-test found the settled
-- formation swept too fast; the existing per-wave ramp below (still
-- +8%/wave) is what was meant by "can ramp up over time", not a
-- separate mechanism
ESPD_BASE=0.2 -- deg/frame formation sweep speed at wave 1
WFC_BASE=90   -- frames, enemy fire-cooldown ceiling at wave 1
DIVE_SPD=2.2  -- px/frame while diving, at wave 1
HITBOX=4      -- px, shared half-width for every shot/enemy/ship collision box
ENT_CAP=64    -- concurrent enemy+enemy-shot cap, bigger canvas than pico-8's 32
-- lives are a life *total*, not a hit counter -- an enemy shot only
-- costs a tenth of a point (10 shots per life), a diving hit costs a
-- full point, same relative severity gap pico-8's undifferentiated
-- "-1 either way" never had. `lv` is fractional now (5 -> 4.9 -> ...),
-- HUD formats it to one decimal (see draw_hud)
SHOT_DMG=0.1
DIVE_DMG=1

-- entrance sequence: every wave starts at the entry points ("planets",
-- see draw_entry_points), circles at length with real lateral drift,
-- then descends into formation -- ported from pico-8's two-phase
-- spiral entry (orbit an entry point, then blend toward the shared
-- centre), not skipped the way an earlier pass here assumed Stage B
-- could get away with. That skip had a real consequence, not just a
-- missing polish pass: with enemies firing from their formation
-- position immediately at wave start, a first live smoke-test emptied
-- all 5 lives before any input could matter, since many enemies sit
-- near ea=0 and fire straight down the same column the ship's own
-- rest position (sang=0) occupies. The entrance sequence fixes that as
-- a side effect of doing it properly: an entering enemy doesn't fire
-- or dive at all (see update_game), so the descent is real breathing
-- room, not a bolted-on grace timer.
--
-- A first pass at this (fixed 8px orbit, 5-15s, same shape every wave)
-- read as too fast and too samey once actually watched play out -- a
-- play-test note asked for it much slower, with more circling and
-- more lateral movement, and for it to vary wave to wave rather than
-- repeat. Four of the five parameters below are now picked fresh per
-- wave in spawn_wave (orbit radius, lateral sway amplitude, orbit
-- direction, and how much of the entrance is spent circling before
-- migrating), not fixed constants, specifically so no two waves'
-- entrances move the same way; ENT_DUR's range moved from 5-15s to
-- 10-25s for the "much slower" ask.
LATERAL_SPD=0.6 -- deg/frame, the slow side-to-side sway layered under the tighter orbit

-- fills `en` for the current wave. Each enemy: tier index, its
-- formation sweep angle (ea) and [lo,hi] bounds it won't sweep past
-- once settled, sweep direction, dive state, fire cooldown (randomized
-- so enemies don't volley in lockstep), which entry point it enters
-- from (ex,ey, alternating left/right by spawn order), its orbit phase
-- offset (ca, spread evenly so entering enemies don't move in
-- lockstep), and `settled` (false until the entrance finishes).
-- Tiers 1-3 get a symmetric band crossing straight-down (deg 0); tier
-- 4's band sits entirely to one side or the other (see the TIERS
-- comment above), so its enemies are pinned to whichever side they
-- spawned on and never cross the excluded near-vertical zone.
function spawn_wave()
 en={}
 eshots={}
 ET=0
 ENT_DUR=600+math.random()*900   -- 10-25s at 60fps, much slower than the first pass's 5-15s
 ENT_ORBIT_R=12+math.random()*12 -- 12-24px tight-orbit radius, varies per wave
 ENT_LAT_AMP=20+math.random()*30 -- 20-50px lateral sway amplitude, varies per wave
 ENT_DIR=math.random()<0.5 and 1 or -1 -- orbit direction, half the waves spin the other way
 ENT_CIRCLE_SPD=2.5+math.random()*1.5  -- 2.5-4 deg/frame, varies per wave
 PHASE1_FRAC=0.5+math.random()*0.2     -- 50-70% of the entrance spent circling before migrating in
 -- count scales with wave, capped at 1.75x wave 1's roster, same
 -- ratio-preserving idea as pico-8's spawn_wave (scale the whole
 -- roster rather than hand-tuning each tier's count per wave)
 local scale=math.min(1.75,1+0.15*(wv-1))
 local counts,total={},0
 for ti,t in ipairs(TIERS) do
  counts[ti]=math.max(1,math.floor(t.n*scale))
  total=total+counts[ti]
 end
 local idx=0
 local function spawn(tier,ea,lo,hi,dir)
  local ex=(idx%2==0) and EX_L or EX_R
  -- x,y start at the entry point itself -- update_game's entrance
  -- branch overwrites this on the very next frame with the real orbit
  -- position, but a wave-clear respawn calls spawn_wave() mid-frame,
  -- after that frame's enemy loop already ran, so these fresh entries
  -- reach draw_enemies() once before update_game() ever touches them.
  -- Without a starting x,y here, that one frame crashes (nil arithmetic
  -- in size_by_y) instead of just briefly showing the ship at the
  -- entry point, which is what it should look like anyway.
  table.insert(en,{tier=tier,ea=ea,lo=lo,hi=hi,dir=dir,dv=0,
   fc=math.random()*WFC_BASE,ex=ex,ey=EX_Y,ca=idx/total*360,settled=false,
   x=ex,y=EX_Y})
  idx=idx+1
 end
 for ti,t in ipairs(TIERS) do
  local n=counts[ti]
  if t.band then
   for i=0,n-1 do
    local frac = n>1 and (i/(n-1)) or 0.5
    spawn(ti,-t.band+frac*(2*t.band),-t.band,t.band,1)
   end
  else
   local per_side=math.floor(n/2)
   for side=-1,1,2 do
    for i=0,per_side-1 do
     local frac = per_side>1 and (i/(per_side-1)) or 0.5
     local ea=side*(t.band_lo+frac*(t.band_hi-t.band_lo))
     local lo,hi
     if side<0 then lo,hi=-t.band_hi,-t.band_lo else lo,hi=t.band_lo,t.band_hi end
     spawn(ti,ea,lo,hi,side)
    end
   end
  end
 end
end

-- e.outer: whichever of [lo,hi] is farthest from straight-down (0) --
-- the edge a dive returns to, same idea as pico-8's "respawns at the
-- outer edge of its arc's angular band, its highest reachable point"
function start_dive(e,shx,shy)
 e.dv=1
 e.outer = (math.abs(e.hi)>math.abs(e.lo)) and e.hi or e.lo
 local dx,dy=shx-e.x,shy-e.y
 local dl=math.max(1,math.sqrt(dx*dx+dy*dy))
 local sp=DIVE_SPD*(1+0.05*(wv-1))
 e.dvx,e.dvy=dx/dl*sp,dy/dl*sp
end

function end_dive(e)
 e.dv=0
 e.ea=e.outer
 e.dir=(e.outer==e.hi) and -1 or 1
end

function update_game()
 if btn(2) then sang=math.max(-SHIP_TRIM,sang-SHIP_STEP) end
 if btn(3) then sang=math.min(SHIP_TRIM,sang+SHIP_STEP) end
 -- up/down step between LANES (a press, not a hold -- btnp, not btn),
 -- one lane per press. The ship doesn't teleport to the new lane
 -- though: cur_a/cur_b ease toward the target lane's shape every
 -- frame (LANE_EASE), landing in a handful of frames -- "slide, but
 -- more like a snap" rather than instant or a slow glide
 if btnp(0) then lane=math.min(#LANES,lane+1) end -- up: next lane in, toward the horizon
 if btnp(1) then lane=math.max(1,lane-1) end       -- down: next lane out
 local ln=LANES[lane]
 cur_a=cur_a+(ln.a-cur_a)*LANE_EASE
 cur_b=cur_b+(ln.b-cur_b)*LANE_EASE
 local shx,shy=lane_xy(cur_a,cur_b,sang)

 if ft>0 then ft=ft-1 end
 if btn(4) and ft<=0 then
  ft=FIRE_CD
  -- aim at the actual centre point, not a radial direction -- on a
  -- circle those are the same thing, but the ship's an ellipse now
  -- (see LANES), so the old dir_xy(sang)-based "inward" trick pointed
  -- somewhere close to, but not exactly at, the centre dot except at
  -- sang=0. A play-test note called this out ("shots feel off ...
  -- should face roughly towards the top centre dot"); aiming at the
  -- real point fixes it exactly, not just approximately.
  local dx,dy=CX-shx,CY-shy
  local dl=math.max(1,math.sqrt(dx*dx+dy*dy))
  table.insert(shots,{x=shx,y=shy,vx=dx/dl*SHOT_SPD,vy=dy/dl*SHOT_SPD})
 end

 for i=#shots,1,-1 do
  local s=shots[i]
  s.x,s.y=s.x+s.vx,s.y+s.vy
  if s.x<0 or s.x>240 or s.y<0 or s.y>136 then table.remove(shots,i) end
 end

 ET=ET+1
 local p1=ENT_DUR*PHASE1_FRAC
 local espd=ESPD_BASE*(1+0.08*(wv-1))
 local dch=math.min(0.5,0.05+0.015*(wv-1))
 local wfc=math.max(20,WFC_BASE-8*(wv-1))
 for i=#en,1,-1 do
  local e=en[i]
  if e.dv==1 then
   e.x,e.y=e.x+e.dvx,e.y+e.dvy
   if math.abs(e.x-shx)<HITBOX and math.abs(e.y-shy)<HITBOX then
    lv=math.max(0,lv-DIVE_DMG)
    end_dive(e)
   elseif e.x<0 or e.x>240 or e.y<0 or e.y>136 then
    end_dive(e)
   end
  elseif not e.settled then
   -- orbit the entry point (tight circle) with a slower, wider lateral
   -- sway layered on top (independent sine, phase-offset by e.ca so
   -- enemies don't sway in lockstep), then blend toward the formation
   -- position; both the orbit and the sway keep advancing through the
   -- blend (not frozen at the phase-1 exit point), so this reads as a
   -- decaying spiral rather than a straight glide, same idea as
   -- pico-8's entrance
   e.ca=e.ca+ENT_CIRCLE_SPD*ENT_DIR
   local rad=math.rad(e.ca)
   local sway=ENT_LAT_AMP*math.sin(math.rad(ET*LATERAL_SPD+e.ca))
   local ox=e.ex+ENT_ORBIT_R*math.sin(rad)+sway
   local oy=e.ey+ENT_ORBIT_R*math.cos(rad)
   if ET<p1 then
    e.x,e.y=ox,oy
   else
    local prog=math.min(1,(ET-p1)/(ENT_DUR-p1))
    local fx,fy=arc_xy(TIERS[e.tier].r,e.ea)
    e.x,e.y=ox+(fx-ox)*prog,oy+(fy-oy)*prog
    if ET>=ENT_DUR then e.settled=true end
   end
  else
   e.ea=e.ea+espd*e.dir
   if e.ea>e.hi then e.ea,e.dir=e.hi,-1
   elseif e.ea<e.lo then e.ea,e.dir=e.lo,1 end
   e.x,e.y=arc_xy(TIERS[e.tier].r,e.ea)

   if e.fc>0 then e.fc=e.fc-1
   else
    e.fc=wfc
    if (#en+#eshots)<ENT_CAP then
     local dx,dy=dir_xy(e.ea)
     table.insert(eshots,{x=e.x,y=e.y,vx=dx*ESHOT_SPD,vy=dy*ESHOT_SPD})
    end
   end
   if math.random()<dch/30 then start_dive(e,shx,shy) end
  end
 end

 for i=#eshots,1,-1 do
  local s=eshots[i]
  s.x,s.y=s.x+s.vx,s.y+s.vy
  if math.abs(s.x-shx)<HITBOX and math.abs(s.y-shy)<HITBOX then
   lv=math.max(0,lv-SHOT_DMG)
   table.remove(eshots,i)
  elseif s.x<0 or s.x>240 or s.y<0 or s.y>136 then
   table.remove(eshots,i)
  end
 end

 for i=#shots,1,-1 do
  local s=shots[i]
  for j=#en,1,-1 do
   local e=en[j]
   if math.abs(s.x-e.x)<HITBOX and math.abs(s.y-e.y)<HITBOX then
    sc=sc+10*e.tier
    table.remove(en,j)
    table.remove(shots,i)
    break
   end
  end
 end

 if lv<=0 then
  over=true -- no end screen yet (Stage C); just stop updating
 elseif #en==0 then
  wv=wv+1
  spawn_wave()
 end
end

function draw_ship()
 -- uses the animated cur_a/cur_b (see update_game), not the target
 -- lane directly, so the drawn ship actually slides/snaps between
 -- lanes instead of teleporting. Size comes from size_by_y, not the
 -- lane -- see that function's comment
 local x,y=lane_xy(cur_a,cur_b,sang)
 local hs=math.max(1,math.floor(size_by_y(y,1,3)+0.5))
 rect(x-hs,y-hs,hs*2,hs*2,7)
 rect(x-1,y-hs,2,math.max(1,hs-1),8) -- trim, scales down with the ship
end

function draw_enemies()
 for _,e in ipairs(en) do
  local t=TIERS[e.tier]
  local maxsz=t.band_lo and 3 or 2 -- tier 4's wing reads slightly bigger at full size, same as before
  circ(e.x,e.y,math.max(1,math.floor(alien_size_by_y(e.y,1,maxsz)+0.5)),t.c)
 end
end

function draw_shots()
 for _,s in ipairs(shots) do circ(s.x,s.y,1,7) end
 for _,s in ipairs(eshots) do circ(s.x,s.y,1,4) end
end

function draw_hud()
 line(0,HUD_Y,240,HUD_Y,7)
 print(string.format("LIVES %.1f",lv),4,HUD_Y+2,7) -- lv is fractional now (SHOT_DMG=0.1/hit), not a whole-hit counter
 print("SCORE "..sc,104,HUD_Y+2,7)
 print("WAVE "..wv,202,HUD_Y+2,7)
end

function BOOT()
 set_palette()
 sang,ft=0,0
 lane=1 -- outer lane, matches R_SHIP (LANES[1].b==R_SHIP)
 cur_a,cur_b=LANES[1].a,LANES[1].b -- start settled on lane 1, not easing in from zero
 shots,eshots,en={},{},{}
 wv,lv,sc=1,5,0
 over=false
 spawn_wave()
end

function TIC()
 if not over then update_game() end
 cls(0)
 draw_sky()
 draw_grid()
 draw_entry_points()
 draw_centre()
 draw_enemies()
 draw_shots()
 draw_ship()
 draw_hud()
end
