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
  elseif mode == "transition" then
    update_transition()
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
  elseif mode == "transition" then
    draw_transition()
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
ph = 2         -- paddle height
br = 2         -- ball radius
pspd = 3       -- paddle speed (px per frame)
bump_dur = 8   -- frames the bump animation lasts
bump_mult = 1.3 -- Speed multiplier for bump
max_spd = 3       -- Top speed for the ball
bump_cd_dur = 20  -- frames between allowed bumps
friction = 0.999  -- velocity multiplier applied each frame (1 = no decay)
min_spd = 1.666   -- minimum absolute y-speed so ball never crawls

bgap = 3       -- gap between bricks (x)
bgap_y = 3     -- gap between brick rows
bstart_y = 10  -- top margin

level_defs = {
  {bw=28, bh=3, bcols=3,  brows=1},
  {bw=28, bh=3, bcols=3,  brows=2},
  {bw=20, bh=3, bcols=4,  brows=2},
  {bw=20, bh=3, bcols=4,  brows=3},
  {bw=14, bh=3, bcols=6,  brows=3},
  {bw=14, bh=3, bcols=6,  brows=4},
  {bw=10, bh=3, bcols=8,  brows=4},
  {bw=10, bh=3, bcols=8,  brows=5},
  {bw=9,  bh=2, bcols=10, brows=5},
  {bw=9,  bh=2, bcols=10, brows=6},
  {bw=7,  bh=2, bcols=12, brows=7},
}

function init_bricks()
  bricks = {}
  local grid_w = bcols * bw + (bcols - 1) * bgap
  local shift = flr((bw + bgap) / 2)
  local extra = brows > 1 and shift or 0
  local ox = flr((128 - grid_w - extra) / 2)
  for r = 0, brows - 1 do
    local row_x = ox + (r % 2 == 1 and shift or 0)
    for c = 0, bcols - 1 do
      add(bricks, {
        x = row_x + c * (bw + bgap),
        y = bstart_y + r * (bh + bgap_y),
        alive = true
      })
    end
  end
end

function apply_level(lvl)
  local def = level_defs[min(lvl, #level_defs)]
  bw = def.bw
  bh = def.bh
  bcols = def.bcols
  brows = def.brows
  init_bricks()
end

function all_cleared()
  for b in all(bricks) do
    if b.alive then return false end
  end
  return true
end

function start_transition()
  level += 1
  apply_level(level)
  trans_timer = 150
  mode = "transition"
end

-- resets all game state, called when starting a new game
function init_game()
  level = 1
  px = 64 - pw / 2
  pdx = 0
  py = 116
  pyo = 0
  pbump = 0
  bump_cd = 0
  bx = 64
  by = py - br
  bdx = 0
  bdy = 0
  pbx = bx
  pby = by
  serving = true
  clear_delay = 0
  apply_level(1)
  trans_timer = 150
  mode = "transition"
end

-- starts bump timer for velocity window; pyo is managed by button state
function do_bump()
  pbump = bump_dur
  bump_cd = bump_cd_dur
  play_sfx(4)
end

function update_game()
  -- snapshot pyo before any changes (used in swept collision)
  local prev_pyo = pyo

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

  -- swept top-face check: use prev_pyo for "was above" so pyo changes don't open gaps
  local crossed_top = pby + br <= py + prev_pyo and by + br >= epy

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

  -- brick collisions
  update_bricks()

  -- level clear delay
  if clear_delay > 0 then
    clear_delay -= 1
    if clear_delay == 0 then start_transition() end
  end

  -- ball lost
  if by - br > 128 then
  		play_sfx(1)
    mode = "gameover"
  end
end

function update_bricks()
  for b in all(bricks) do
    if b.alive then
      local hit = bx+br > b.x and bx-br < b.x+bw
              and by+br > b.y and by-br < b.y+bh
      if hit then
        b.alive = false
        local was_above = pby + br <= b.y
        local was_below = pby - br >= b.y + bh
        if was_above or was_below then
          bdy = -bdy
        else
          bdx = -bdx
        end
        play_sfx(3)
        if all_cleared() then clear_delay = 15 end
      end
    end
  end
end

function update_transition()
  local prev_px = px
  if btn_held(btn_left) then px = max(0, px - pspd) end
  if btn_held(btn_right) then px = min(128 - pw, px + pspd) end
  pdx = px - prev_px

  if pbump > 0 then pbump -= 1 end
  if bump_cd > 0 then bump_cd -= 1 end

  if not serving then
    if btn_pressed(btn_x) and bump_cd == 0 then do_bump() end
    pyo = btn_held(btn_x) and -1 or 0
  end

  if serving then
    bx = px + pw / 2
    by = py + pyo - br
  end
  trans_timer -= 1
  if serving then
    if trans_timer <= 90 then mode = "game" end
  else
    if trans_timer <= 0 then mode = "game" end
  end
end

function draw_transition()
  draw_game()
  local msg, col
  if serving then
    msg = "level "..level
    col = 7
  else
    local phase = flr((trans_timer - 1) / 30)
    if phase == 4 then
      msg = "level "..level  col = 7
    elseif phase == 3 then
      msg = "3"              col = 8
    elseif phase == 2 then
      msg = "2"              col = 9
    elseif phase == 1 then
      msg = "1"              col = 10
    else
      msg = "go!"            col = 11
    end
  end
  local x = 64 - #msg * 4
  print("\^w\^t"..msg, x, 56, col)
end

function draw_bricks()
  for b in all(bricks) do
    if b.alive then
      rectfill(b.x+1, b.y+1, b.x+bw+1, b.y+bh+1, 0)
      rectfill(b.x, b.y, b.x+bw, b.y+bh, 5)
    end
  end
end

function draw_game()
  draw_bricks()
  -- drop shadows
  rectfill(px+1, py+1, px+pw+1, py+ph+1, 0)
  circfill(bx+1, by+1, br, 0)
  -- paddle and ball
  rectfill(px, py+pyo, px+pw, py+pyo+ph, 13)
  circfill(bx, by, br, 13)
  -- shine
  pset(bx-1, by-1, 7)
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
00010000020100301004010070200a0200d02010020150201a0102001026010007000000022000220000000000000210002100000000000001e0001f000000000000000000190001800000000000000000000000
000100000e6200f6200f6200f6200d7300d7300d7300c7300c7300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000019010130100e010210002100021000200001e0001b0001900017000130001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
