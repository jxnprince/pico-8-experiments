pico-8 cartridge // http://www.pico-8.com
version 43
__lua__

--> Baseline

-- global state: current screen/phase
function _init()
  btn_left  = 0
  btn_right = 1
  btn_up    = 2
  btn_down  = 3
  btn_x     = 4
  btn_o     = 5
  input = {}

  settings = settings or { palette_i = 1 }

  mode = "start"
end

-- routes update to current mode each frame
function _update60()
  update_input()
  if mode == "start" then
    update_start()
  elseif mode == "game" then
    update_game()
  elseif mode == "gameover" then
    update_gameover()
  end
end

-- clears screen and routes draw to current mode
function _draw()
  cls(1)
  if mode == "start" then
    draw_start()
  elseif mode == "game" then
    draw_game()
  elseif mode == "gameover" then
    draw_gameover()
  end
end

-- wrapper for future sfx vol control
function play_sfx(id)
  sfx(id)
end

-- wrapper for future music vol control
function play_music(id)
  music(id)
end

--> Input Handling

-- tracks held and just-pressed state for all 6 buttons each frame
function update_input(p)
  p = p or 0
  input.held = input.held or {}
  input.pressed = {}
  for b = 0, 5 do
    local down = btn(b, p)
    input.pressed[b] = down and not input.held[b]
    input.held[b] = down
  end
end

-- true while button is held
function btn_held(b)
  return input.held[b]
end

-- true only on the frame the button was first pressed
function btn_pressed(b)
  return input.pressed[b]
end

--> START UP

function update_start()
  if btn_pressed(btn_x) then
    init_game()
    mode = "game"
  end
end

function draw_start()
  print("❎ start", 46, 70, 14)
end

--> GAME OVER

function update_gameover()
  if btn_pressed(btn_x) then
    mode = "start"
  end
end

function draw_gameover()
  print("game over", 42, 55, 9)
  print("❎ to restart", 36, 70, 14)
end

--> GAMEPLAY

pw = 24        -- paddle width
ph = 3         -- paddle height
br = 2         -- ball radius
pspd = 3       -- paddle speed (px per frame)
bump_dur = 8   -- frames the bump animation lasts
bump_mult = 1.3 -- Speed multiplier for bump
max_spd = 3       -- Top speed for the ball
bump_cd_dur = 20  -- frames between allowed bumps
friction = 0.999  -- velocity multiplier applied each frame (1 = no decay)
min_spd = 1.666   -- minimum absolute y-speed so ball never crawls

-- resets all game state, called when starting a new game
function init_game()
  px = 64 - pw / 2
  pdx = 0  -- paddle velocity this frame
  py = 116
  pyo = 0      -- paddle y offset (bump animation)
  pbump = 0    -- bump timer
  bump_cd = 0  -- bump cooldown timer
  bx = 64
  by = py - br
  bdx = 0
  bdy = 0
  pbx = bx
  pby = by
  serving = true
end

-- starts bump timer for velocity window; pyo is managed by button state
function do_bump()
  pbump = bump_dur
  bump_cd = bump_cd_dur
  play_sfx(4)
end

function update_game()
  -- move paddle, track velocity
  local prev_px = px
  if btn_held(btn_left) then
    px = max(0, px - pspd)
  end
  if btn_held(btn_right) then
    px = min(128 - pw, px + pspd)
  end
  pdx = px - prev_px

  -- tick bump and cooldown timers
  if pbump > 0 then pbump -= 1 end
  if bump_cd > 0 then bump_cd -= 1 end

  -- x triggers bump during gameplay if cooldown is clear
  if not serving and btn_pressed(btn_x) and bump_cd == 0 then
    do_bump()
  end

  -- paddle stays up while x is held, returns when released
  if not serving then
    pyo = btn_held(btn_x) and -1 or 0
  end

  -- ball follows paddle until served
  if serving then
    bx = px + pw / 2
    by = py + pyo - br
    if btn_pressed(btn_x) then
      do_bump()
      local dir = 0
      if btn_held(btn_left) then dir = -1
      elseif btn_held(btn_right) then dir = 1
      end
      -- add small random offset so serve is never perfectly vertical
      bdx = (dir * 1.5 + rnd(0.6) - 0.3) * bump_mult
      bdy = -1.5 * bump_mult
      serving = false
    end
    return
  end

  -- store previous ball position before moving
  pbx = bx
  pby = by

  bx += bdx
  by += bdy

  -- apply friction and enforce minimum speeds
  bdx *= friction
  bdy *= friction
  if abs(bdy) < min_spd then
    bdy = min_spd * sgn(bdy)
  end
  -- wall bounces
  if bx - br < 0 then
    bx = br
    bdx = -bdx
    play_sfx(0)
  end
  if bx + br > 127 then
    bx = 127 - br
    bdx = -bdx
    play_sfx(0)
  end
  if by - br < 0 then
    by = br
    bdy = -bdy
    play_sfx(0)
  end

  -- effective paddle top accounts for bump offset
  local epy = py + pyo

  local in_x = bx + br >= px and bx - br <= px + pw

  -- swept top-face check: did ball cross paddle top this frame?
  local crossed_top = pby + br <= epy and by + br >= epy

  if crossed_top and in_x then
    by = epy - br
    bdy = -abs(bdy)
    -- blend incoming bdx with hit position angle and paddle velocity
    local hit = (bx - px) / pw  -- 0..1
    local angle_bdx = (hit - 0.5) * 4
    bdx = bdx * 0.5 + angle_bdx * 0.2 + pdx * 0.5
    if pbump > 0 then
      bdx = mid(-max_spd, bdx * bump_mult, max_spd)
      bdy = mid(-max_spd, bdy * bump_mult, -0.5)
      pbump = 0
      play_sfx(2)
    else
      play_sfx(3)
    end
  elseif not crossed_top then
    -- side collision: ball entered paddle from left or right
    local in_y = by + br >= epy and by - br <= epy + ph
    if in_y then
      if pbx + br < px and bx + br >= px then
        bdx = abs(bdx)
      elseif pbx - br > px + pw and bx - br <= px + pw then
        bdx = -abs(bdx)
      end
    end
  end

  -- ball lost
  if by - br > 128 then
  		play_sfx(1)
    mode = "gameover"
  end
end

function draw_game()
  rectfill(px, py + pyo, px + pw, py + pyo + ph, 7)
  circfill(bx, by, br, 7)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100000b63009050080400704007030050300403003020020200102000030000300003000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000000203a71038710357103371031710300102f0102d0102b01029010270102601025110231102211020110201101e1101d1101b11019210162101421012210112100e3100c3100a310074100641003410
0001000025710277102a7102c7202e72031720337203572037710397103f710007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000e6200f6200f6200f6200d7300d7300d7300c7300c7300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000210102101021010210102101021010200101e0101b0101901017020130201102000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
