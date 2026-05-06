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

  cartdata("jxn_breakout_v3")
  hs_init()
  resolve_palette(settings.palette_i)
  mode = "start"
end

-- routes update to current mode each frame
function _update60()
  update_input()
  if mode == "start" then
    update_start()
  elseif mode == "game" then
    update_game()
    update_particles()
  elseif mode == "transition" then
    update_transition()
    update_particles()
  elseif mode == "gameover" then
    update_gameover()
    update_particles()
  elseif mode == "win" then
    update_win()
  elseif mode == "hiscore" then
    update_hiscore()
  elseif mode == "initials" then
    update_initials()
  end
end

-- clears screen and routes draw to current mode
function _draw()
  apply_palette()
  cls(1)
  if mode == "start" then
    draw_start()
  elseif mode == "game" then
    draw_game()
  elseif mode == "transition" then
    draw_transition()
  elseif mode == "gameover" then
    draw_gameover()
  elseif mode == "win" then
    draw_win()
  elseif mode == "hiscore" then
    draw_hiscore()
  elseif mode == "initials" then
    draw_initials()
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

--> PALETTES

palette_names = {
  "classic",
  "submarine",
  "pastel",
  "matcha",
  "rhenium",
  "bokju",
  "pong",
  "g boy",
  "v boy",
  "random"
}

-- {bg, mid, fg, hi, alert, lo}
-- bg=background
-- mid=bricks/hud text
-- fg=paddle+ball
-- hi=titles/highlights
-- alert=hearts/damage
-- lo=shadows
palettes = {
  {1, 13, 13, 7,  8, -16},       -- classic
  {-13, -8, 13, 7, -8, -15},     -- submarine
  {-4, -2, 12, 7, -8, 1},        -- pastel
  {3, -5, 11, -6, -2, -13},      -- matcha
  {-15, 14, -2, 15, -1, -3},     -- rhenium
  {5, 6, 6, -10, 7, 0},          -- bokju
  {0, 7, 7, 7, 7, 0},            -- pong
  {-6, -5, -5, -9, 3, -13},      -- game boy
  {0, -8, -8, 7, 8, -14},        -- virtual boy
  {-17,-17, -17, -17, -17, -17}, -- random
}


cur_palette = {}

function resolve_palette(i)
  local p = palettes[i]
  cur_palette = {}
  for j = 1, 6 do
    local c = p[j]
    cur_palette[j] = (c == -17) and flr(rnd(32)) - 16 or c
  end
end

function apply_palette()
  local c = cur_palette
  pal()
  pal(1,  c[1], 1)  -- bg
  pal(5,  c[2], 1)  -- mid
  pal(6,  c[2], 1)  -- mid
  pal(3,  c[2], 1)  -- mid
  pal(13, c[3], 1)  -- fg
  pal(14, c[3], 1)  -- fg
  pal(12, c[3], 1)  -- fg
  pal(7,  c[4], 1)  -- hi
  pal(10, c[4], 1)  -- hi
  pal(11, c[4], 1)  -- hi
  pal(8,  c[5], 1)  -- alert
  pal(9,  c[5], 1)  -- alert
  pal(2,  c[5], 1)  -- alert
  pal(0,  c[6], 1)  -- lo (shadows)
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

  if btn_pressed(btn_up) then
    settings.palette_i = settings.palette_i % #palettes + 1
    resolve_palette(settings.palette_i)
    play_sfx(6)
  elseif btn_pressed(btn_down) then
    settings.palette_i = (settings.palette_i - 2) % #palettes + 1
    resolve_palette(settings.palette_i)
    play_sfx(7)
  end

  if btn_pressed(btn_x) then
    play_sfx(8)
    init_game(sel_level)
  end
  if btn_pressed(btn_o) then
    mode = "hiscore"
  end
end

function draw_start()
  -- nav controls group
  local lbl = "level "..(sel_level < 10 and " " or "")..sel_level
  local lx = 64 - #lbl * 2
  print("⬅️", lx - 10, 94, 6)
  print(lbl, lx, 94, 7)
  print("➡️", lx + #lbl * 4 + 2, 94, 6)

  local pn = palette_names[settings.palette_i]
  local ppx = 64 - #pn * 2
  print("⬆️", ppx - 10, 104, 6)
  print(pn, ppx, 104, 5)
  print("⬇️", ppx + #pn * 4 + 2, 104, 6)

  -- action buttons: same row near bottom
  -- ❎ start = 32px, gap 6px, 🅾️ hi scores = 48px ヌ●★ total 86px centered
  print("❎ start", 21, 119, 14)
  print("🅾️ hi scores", 59, 119, 14)
end

--> WIN

function update_win()
  if btn_pressed(btn_x) then
    sel_level = 1
    mode = "start"
  end
end

function draw_win()
  local title = "you win!"
  print("\^w\^t"..title, 64 - #title * 4, 36, 11)
  local sc = fmt_score()
  print(sc, 64 - #sc * 2, 62, 7)
  print("❎ to start", 40, 78, 14)
end

--> GAME OVER

function update_gameover()
  if go_flash > 0 then
    go_flash -= 1
    if go_flash == 0 and new_hs_pos then
      init_initials()
    end
    return
  end
  if btn_pressed(btn_x) then
    init_game(level)
  elseif btn_pressed(btn_o) then
    mode = "hiscore"
  end
end

function draw_gameover()
  if go_flash > 25 then
    draw_game()
  else
    print("\^w\^tgame over", 28, 28, 8)
    local lvl = "level "..level
    print(lvl, 64 - #lvl * 2, 48, 6)
    local sc = fmt_score()
    print(sc, 64 - #sc * 2, 58, 7)
    if go_flash == 0 then
      if new_hs_pos then
        print("new hi score!", 64-13*2, 70, 10)
      end
      print("❎ retry", 46, 80, 14)
      print("🅾️ hi scores", 46, 88, 14)
    else
      local p = go_flash > 18 and 0xeeee or (go_flash > 12 and 0xcccc or (go_flash > 6 and 0x8888 or 0x2222))
      fillp(p)
      rectfill(0, 0, 127, 127, 1)
      fillp()
    end
  end
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
  if level > #level_defs then
    mode = "win"
    return
  end
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
  go_flash = 0
  new_hs_pos = nil
  particles = {}
  volley = 0
  plean = 0
  poff = 0
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
  local lean_dir = btn_held(btn_right) and 1 or btn_held(btn_left) and -1 or 0
  plean += (lean_dir - plean) * 0.12
  poff = flr(plean * 3)

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
      volley = 0
    end
    return
  end

  -- store previous ball position before moving
  pbx = bx
  pby = by

  bx += bdx
  by += bdy

  -- trail: count scales from 1 at min threshold to 4 at max speed
  local spd = sqrt(bdx*bdx + bdy*bdy)
  local trail_min = min_spd * 1.8
  if spd > trail_min then
    local t = min(1, (spd - trail_min) / (max_spd - trail_min))
    local count = 1 + flr(t * 3)
    for i = 1, count do
      spawn_particle(pbx+rnd(2)-1, pby+rnd(2)-1,
                     bdx*0.05, bdy*0.05,
                     8+flr(rnd(8)), 13, 1, 0)
    end
  end

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

  local hx_l = px + min(0, poff)
  local hx_r = px + pw + max(0, poff)
  local in_x = bx + br >= hx_l and bx - br <= hx_r

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
        volley = 0
        local shine = {{7,5},{7,6},{5,6}}
        for i = 1, 6 do
          local a = rnd(1)
          local s = 0.5 + rnd(0.9)
          local pair = shine[flr(rnd(3))+1]
          spawn_particle(bx, by,
                         cos(a)*s, sin(a)*s - 0.2,
                         16+flr(rnd(12)), pair[1], pair[2], 0, 1)
        end
      else
        play_sfx(5)
        volley = 0
      end
    elseif not crossed_top then
      local in_y = by + br >= epy and by - br <= epy + ph
      if in_y then
        if pbx + br < hx_l and bx + br >= hx_l then
          bdx = abs(bdx)
        elseif pbx - br > hx_r and bx - br <= hx_r then
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
      volley = 0
      for i = 1, 8 do
        spawn_particle(bx+rnd(6)-3, 127-br,
                       bdx*0.2 + rnd(3)-1.5, -(1+rnd(2.5)),
                       20+flr(rnd(20)), 9, 8, 0.06)
      end
    else
      play_sfx(9)
      volley = 0
      for i = 1, 14 do
        spawn_particle(bx+rnd(6)-3, 127-br,
                       bdx*0.3 + rnd(4)-2, -(1.5+rnd(3)),
                       30+flr(rnd(30)), 8, 2, 0.06)
      end
      new_hs_pos = hs_check(score_hi, score_lo)
      go_flash = 145
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
        volley += 1
        local cx = b.x + bw/2
        local cy = b.y + bh/2
        local pcount = min(3 + volley, 14)
        for i = 1, pcount do
          local a = rnd(1)
          local s = 0.5 + rnd(1.5)
          spawn_particle(cx, cy,
                         cos(a)*s + bdx*0.2, sin(a)*s + bdy*0.2,
                         20+flr(rnd(20)), 6, 5, 0.05)
        end
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
  local lean_dir = btn_held(btn_right) and 1 or btn_held(btn_left) and -1 or 0
  plean += (lean_dir - plean) * 0.12
  poff = flr(plean * 3)

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
    col = 13
  else
    local phase = flr((trans_timer - 1) / 30)
    if phase == 4 then
      msg = "level "..level  col = 13
    elseif phase == 3 then
      msg = "3"              col = 13
    elseif phase == 2 then
      msg = "2"              col = 13
    elseif phase == 1 then
      msg = "1"              col = 13
    else
      msg = "go!"            col = 7
    end
  end
  local x = 64 - #msg * 4
  print("\^w\^t"..msg, x+1, 57, 0)
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

function fmt_score(shi, slo)
  shi = shi or score_hi or 0
  slo = slo or score_lo or 0
  local lo = tostr(slo)
  while #lo < 4 do lo = "0"..lo end
  local s = shi > 0 and tostr(shi)..lo or tostr(slo)
  local r = ""
  for i = 1, #s do
    if i > 1 and (#s - i + 1) % 3 == 0 then r = r.."," end
    r = r..sub(s, i, i)
  end
  return r
end

function draw_hud()
  rectfill(0, 0, 127, 8, 0)
  print("l"..level, 1, 1, 7)
  local lhp = ""
  for i = 1, lives do lhp = lhp.."♥" end
  if lives > 0 then print(lhp, 17, 1, 8) end
  local sc = fmt_score()
  print(sc, 127 - #sc * 4, 1, 7)
end

--> PARTICLES

function spawn_particle(x, y, dx, dy, life, col1, col2, grav, sz)
  if #particles >= 80 then return end
  add(particles, {
    x=x, y=y, dx=dx, dy=dy,
    life=life, max_life=life,
    col1=col1, col2=col2,
    grav=grav or 0,
    sz=sz or 0
  })
end

function update_particles()
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.x += p.dx
    p.y += p.dy
    p.dy += p.grav
    p.life -= 1
    if p.life <= 0 then deli(particles, i) end
  end
end

function draw_particles()
  for p in all(particles) do
    local t = p.life / p.max_life
    local col = t > 0.5 and p.col1 or p.col2
    if p.sz == 1 and t > 0.5 then
      circfill(p.x, p.y, 1, col)
    else
      pset(p.x, p.y, col)
    end
  end
end

--> HIGH SCORES

hs_max = 10
ini_set = 37  -- A-Z (0-25), 0-9 (26-35), space (36)

function ini_chr(i)
  if i < 26 then return chr(i+65)
  elseif i < 36 then return chr(i-26+48)
  else return " " end
end

function fmt_ini(c1, c2, c3)
  return ini_chr(c1)..ini_chr(c2)..ini_chr(c3)
end

function hs_load()
  hs = {}
  for i = 1, hs_max do
    local b = (i-1)*6
    add(hs, {
      shi=dget(b), slo=dget(b+1), lvl=dget(b+2),
      c1=dget(b+3), c2=dget(b+4), c3=dget(b+5)
    })
  end
end

function hs_save()
  for i = 1, hs_max do
    local b = (i-1)*6
    local e = hs[i]
    dset(b,e.shi) dset(b+1,e.slo) dset(b+2,e.lvl)
    dset(b+3,e.c1) dset(b+4,e.c2) dset(b+5,e.c3)
  end
end

function hs_init()
  if dget(60) != 1 then
    hs = {
      {shi=5000,slo=0,lvl=21,c1=0, c2=18,c3=18}, -- ASS
      {shi=2000,slo=0,lvl=16,c1=15,c2=4, c3=4},  -- PEE
      {shi=500, slo=0,lvl=9, c1=3, c2=8, c3=10}, -- DIK
    }
    for i=4,hs_max do add(hs,{shi=0,slo=0,lvl=0,c1=0,c2=0,c3=0}) end
    hs_save()
    dset(60,1)
  else
    hs_load()
  end
end

function hs_check(shi, slo)
  for i = 1, hs_max do
    local e = hs[i]
    if shi > e.shi or (shi == e.shi and slo > e.slo) then
      return i
    end
  end
end

function hs_insert(pos, shi, slo, lvl, c1, c2, c3)
  for i = hs_max, pos+1, -1 do hs[i] = hs[i-1] end
  hs[pos] = {shi=shi,slo=slo,lvl=lvl,c1=c1,c2=c2,c3=c3}
  hs_save()
end

-- initials entry

function init_initials()
  ini_chars = {0,0,0}
  ini_pos = 1
  ini_rep_ud = 0
  mode = "initials"
end

function update_initials()
  local mud = false

  if btn_pressed(btn_up) then
    ini_chars[ini_pos] = (ini_chars[ini_pos]-1)%ini_set
    ini_rep_ud = 20; mud = -1
  elseif btn_held(btn_up) then
    ini_rep_ud -= 1
    if ini_rep_ud <= 0 then
      ini_chars[ini_pos] = (ini_chars[ini_pos]-1)%ini_set
      ini_rep_ud = 4; mud = -1
    end
  elseif btn_pressed(btn_down) then
    ini_chars[ini_pos] = (ini_chars[ini_pos]+1)%ini_set
    ini_rep_ud = 20; mud = 1
  elseif btn_held(btn_down) then
    ini_rep_ud -= 1
    if ini_rep_ud <= 0 then
      ini_chars[ini_pos] = (ini_chars[ini_pos]+1)%ini_set
      ini_rep_ud = 4; mud = 1
    end
  end

  if mud == -1 then play_sfx(6)
  elseif mud == 1 then play_sfx(7)
  end

  if btn_pressed(btn_x) then
    if ini_pos < 3 then
      ini_pos += 1
      play_sfx(6)
    else
      hs_insert(new_hs_pos,score_hi,score_lo,level,
                ini_chars[1],ini_chars[2],ini_chars[3])
      play_sfx(10)
      mode = "hiscore"
    end
  elseif btn_pressed(btn_o) and ini_pos > 1 then
    ini_pos -= 1
    play_sfx(7)
  end
end

function draw_initials()
  print("\^w\^tnew best!", 24, 16, 10)
  local sc = fmt_score()
  print(sc, 64-#sc*2, 40, 7)
  local lvl_s = "level "..level
  print(lvl_s, 64-#lvl_s*2, 50, 6)
  print("enter initials", 64-14*2, 66, 5)
  for i = 1, 3 do
    local cx = 48+(i-1)*12
    local col = i < ini_pos and 11 or i == ini_pos and 7 or 5
    print("\^w\^t"..ini_chr(ini_chars[i]), cx, 78, col)
    if i == ini_pos then line(cx,93,cx+7,93,7) end
  end
  local prompt = ini_pos < 3 and "❎ next" or "❎ submit"
  print(prompt, 64-#prompt*2, 108, 14)
  if ini_pos > 1 then print("🅾️ back", 64-7*2, 116, 5) end
end

-- high score display

function update_hiscore()
  if btn_pressed(btn_x) or btn_pressed(btn_o) then
    sel_level = 1
    mode = "start"
  end
end

function draw_hiscore()
  print("high scores", 64-11*2, 2, 10)
  for i = 1, hs_max do
    local e = hs[i]
    local y = 13+(i-1)*10
    local has = e.shi>0 or e.slo>0
    local col = has and 7 or 5
    print(i..".", 2, y, col)
    print(has and fmt_ini(e.c1,e.c2,e.c3) or "---", 16, y, col)
    if has then
      local sc = fmt_score(e.shi,e.slo)
      print(sc, 96-#sc*4, y, col)
      print("l"..e.lvl, 102, y, 6)
    end
  end
  print("❎ / 🅾️ menu", 50, 118, 14)
end

function draw_game()
  draw_particles()
  draw_bricks()
  draw_hud()
  -- drop shadows
  rectfill(px+1+poff, py+1, px+pw+1+poff, py+ph+1, 0)
  circfill(bx+1, by+1, br, 0)
  -- afterimage extends the trail visually
  if not serving then
    circfill(pbx, pby, br, 1)
  end
  -- paddle and ball
  rectfill(px+poff, py+pyo, px+pw+poff, py+pyo+ph, 13)
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
