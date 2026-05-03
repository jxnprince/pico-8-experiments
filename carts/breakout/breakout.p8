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
  sel_level = 1
  sel_repeat = 0

  local tb = 0
  for i = 1, #level_defs do
    tb += level_defs[i].bcols * level_defs[i].brows
  end
  local tgt = flr(32767 * 9 / 10)
  brick_val_hi = flr(tgt / tb)
  local rem = tgt - brick_val_hi * tb
  brick_val_lo = flr(rem / tb * 10000)

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
  local n = #level_defs
  local moved = false

  if btn_pressed(btn_left) then
    sel_level = (sel_level - 2) % n + 1
    sel_repeat = 20
    moved = -1
  elseif btn_held(btn_left) then
    sel_repeat -= 1
    if sel_repeat <= 0 then
      sel_level = (sel_level - 2) % n + 1
      sel_repeat = 4
      moved = -1
    end
  elseif btn_pressed(btn_right) then
    sel_level = sel_level % n + 1
    sel_repeat = 20
    moved = 1
  elseif btn_held(btn_right) then
    sel_repeat -= 1
    if sel_repeat <= 0 then
      sel_level = sel_level % n + 1
      sel_repeat = 4
      moved = 1
    end
  end

  if moved == 1 then play_sfx(6)
  elseif moved == -1 then play_sfx(7)
  end

  if btn_pressed(btn_x) then
    play_sfx(8)
    init_game(sel_level)
  end
end

function draw_start()
  local lbl = "level "..sel_level
  local lx = 64 - #lbl * 2
  print("<", lx - 6, 60, 6)
  print(lbl, lx, 60, 7)
  print(">", lx + #lbl * 4 + 2, 60, 6)
  print("❎ start", 50, 74, 14)
end

--> GAME OVER

function update_gameover()
  if btn_pressed(btn_x) then
    sel_level = level
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
pspd = 3.2     -- paddle speed (px per frame)
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
  {bw=28, bh=3, bcols=4,  brows=1}, -- 1
  {bw=28, bh=3, bcols=4,  brows=2}, -- 2
  {bw=28, bh=3, bcols=4,  brows=4}, -- 3
  {bw=20, bh=3, bcols=5,  brows=2}, -- 4
  {bw=20, bh=3, bcols=5,  brows=4}, -- 5
  {bw=20, bh=3, bcols=5,  brows=6}, -- 6
  {bw=14, bh=3, bcols=7,  brows=4}, -- 7
  {bw=14, bh=3, bcols=7,  brows=6}, -- 8
  {bw=10, bh=3, bcols=9,  brows=2}, -- 9
  {bw=10, bh=3, bcols=9,  brows=4}, -- 10
  {bw=10, bh=3, bcols=9,  brows=6}, -- 11
  {bw=10, bh=2, bcols=9,  brows=4}, -- 12
  {bw=10, bh=2, bcols=9,  brows=6}, -- 13
  {bw=9,  bh=2, bcols=10, brows=6}, -- 14
  {bw=8,  bh=2, bcols=11, brows=6}, -- 15
  {bw=7,  bh=2, bcols=11, brows=6}, -- 16
  {bw=6,  bh=2, bcols=13, brows=6}, -- 17
  {bw=5,  bh=2, bcols=15, brows=6}, -- 18
  {bw=4,  bh=2, bcols=18, brows=6}, -- 19
  {bw=3,  bh=2, bcols=21, brows=6}, -- 20
  {bw=1,  bh=2, bcols=30, brows=6}, -- 21
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
function init_game(start_lvl)
  level = start_lvl or 1
  px = 64 - pw / 2
  pdx = 0
  py = 120
  pyo = 0
  pbump = 0
  bump_cd = 0
  bx = 64
  by = py - br
  bdx = 0
  bdy = 0
  pbx = bx
  pby = by
  lives = 2
  score_hi = 0
  score_lo = 0
  life_flash_t = 0
  paddle_passthrough = false
  ball_in_score = false
  serving = true
  clear_delay = 0
  apply_level(level)
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

  if not paddle_passthrough then
    if crossed_top and in_x then
      by = epy - br
      bdy = -abs(bdy)
      local hit = (bx - px) / pw
      local angle_bdx = (hit - 0.5) * 4
      bdx = bdx * 0.5 + angle_bdx * 0.2 + pdx * 0.5
      if pbump > 0 then
        bdx = mid(-max_spd, bdx * bump_mult, max_spd)
        bdy = mid(-max_spd, bdy * bump_mult, -0.5)
        pbump = 0
        play_sfx(2)
      else
        play_sfx(5)
      end
    elseif not crossed_top then
      local in_y = by + br >= epy and by - br <= epy + ph
      if in_y then
        if pbx + br < px and bx + br >= px then
          bdx = abs(bdx)
        elseif pbx - br > px + pw and bx - br <= px + pw then
          bdx = -abs(bdx)
        end
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

  -- score hud overlap sfx
  local sc_x = 127 - #fmt_score() * 4
  local in_score = by - br < 8 and bx + br >= sc_x
  if in_score and not ball_in_score then play_sfx(10) end
  ball_in_score = in_score

  -- clear passthrough once ball is safely above paddle
  if paddle_passthrough and by < py - 20 then
    paddle_passthrough = false
  end

  -- tick life flash
  if life_flash_t > 0 then life_flash_t -= 1 end

  -- bottom collision
  if by + br > 127 then
    if lives > 0 then
      by = 127 - br
      bdy = -abs(bdy)
      bdx = flr(bdx / 2)
      bdy = flr(bdy / 2)
      if abs(bdy) < min_spd then bdy = -min_spd end
      lives -= 1
      life_flash_t = 45
      paddle_passthrough = true
      play_sfx(1)
    else
      play_sfx(9)
      score_hi = 0
      score_lo = 0
      mode = "gameover"
    end
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
        add_score()
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

function add_score()
  local spd = sqrt(bdx*bdx + bdy*bdy)
  local factor = max(1, spd / min_spd) * (level / #level_defs)
  local slo = flr(brick_val_lo * factor)
  local shi = flr(brick_val_hi * factor) + flr(slo / 10000)
  score_lo += slo % 10000
  if score_lo >= 10000 then
    score_hi += flr(score_lo / 10000)
    score_lo = score_lo % 10000
  end
  score_hi += shi
end

function fmt_score()
  local lo = tostr(score_lo)
  while #lo < 4 do lo = "0"..lo end
  local s = score_hi > 0 and tostr(score_hi)..lo or tostr(score_lo)
  local r = ""
  for i = 1, #s do
    if i > 1 and (#s - i + 1) % 3 == 0 then r = r.."," end
    r = r..sub(s, i, i)
  end
  return r
end

function draw_hud()
  rectfill(0, 0, 127, 8, 0)
  print("l"..level, 1, 1, 6)
  local lhp = lives > 0 and "" or "♥"
  for i = 1, lives do lhp = lhp.."♥" end
  print(lhp, 17, 1, lives > 0 and 8 or 5)
  local sc = fmt_score()
  print(sc, 127 - #sc * 4, 1, 7)
end

function draw_game()
  draw_bricks()
  draw_hud()
  -- drop shadows
  rectfill(px+1, py+1, px+pw+1, py+ph+1, 0)
  circfill(bx+1, by+1, br, 0)
  -- paddle and ball
  rectfill(px, py+pyo, px+pw, py+pyo+ph, 13)
  circfill(bx, by, br, 13)
  -- shine
  pset(bx-1, by-1, 7)
  -- life lost flash
  if life_flash_t > 0 then
    local col = life_flash_t > 30 and 7 or (life_flash_t > 15 and 8 or 2)
    print("-1♥", 52, 56, col)
  end
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
00020000146201462038720357203372031710300102f0102d0102b01029010270102601025110231102211020110201101e1101d1101b11019210162101421012210112100e3100c3100a310074100641003410
000100000e6100301004010070200a0200d02010020150201a0102001026010007000000022000220000000000000210002100000000000001e0001f000000000000000000190001800000000000000000000000
000100000371004610066100a6100c7200b7200972007720077200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000019020130200e020050302100021000200001e0001b0001900017000130001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000018020116200c0200902002020020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002801000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001f01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000704008040090400b0300c0300d0300f030100301302016020190201b0201e01024010290102d01035010000000000000000000000000000000000000000000000000000000000000000000000000000
000200001a4202043024440286502d6503365034650336402f6402a63027630226301f6201f6201e6201d6101c6101a6201862013410134101241011420104300f4200d4200b4300942008420064200441000450
0003000014620146201462019600302002c6202c6202f2203722039200382003d2003f20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
