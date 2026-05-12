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

  sel_level = 1
  sel_repeat = 0
  nudge_l = 0; nudge_r = 0; nudge_u = 0; nudge_d = 0
  hs_from_gameover = false; hs_entry_done = true; retry_from = "gameover"; hs_can_retry = false
  go_cursor = 1; win_cursor = 1; wall_sfx_t = 0; traj_phase = 0
  bark_msg = ""; bark_t = 0; bark_exit_t = 0; bark_enter_t = 0; bark_col = 7; bark_dir = 1; bark_amp = 1; bark_y = 56

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
  local saved_p = dget(61)
  settings = { palette_i = (saved_p >= 1 and saved_p <= #palettes) and saved_p or 1 }
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
    update_hearts()
    update_falling_pus()
    update_particles()
    update_bark()
  elseif mode == "transition" then
    update_transition()
    update_particles()
    update_bark()
  elseif mode == "gameover" then
    update_gameover()
    update_particles()
    update_bark()
  elseif mode == "win" then
    update_win()
  elseif mode == "hiscore" then
    update_hiscore()
  elseif mode == "confirm_retry" then
    update_confirm_retry()
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
  elseif mode == "confirm_retry" then
    draw_confirm_retry()
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
  input.released = {}
  for b = 0, 5 do
    local down = btn(b, p)
    input.pressed[b]  = down and not input.held[b]
    input.released[b] = not down and input.held[b]
    input.held[b] = down
  end
end

function btn_held(b)    return input.held[b]     end
function btn_pressed(b) return input.pressed[b]  end
function btn_released(b) return input.released[b] end

--> PALETTES

palette_names = {
  "classic",
  "sub",
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
  {-13, -8, 13, 7, -8, -15},     -- sub
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

  if moved == 1 then play_sfx(6); nudge_r = 6
  elseif moved == -1 then play_sfx(7); nudge_l = 6
  end

  if btn_pressed(btn_up) then
    settings.palette_i = settings.palette_i % #palettes + 1
    resolve_palette(settings.palette_i)
    dset(61, settings.palette_i)
    play_sfx(6); nudge_u = 6
  elseif btn_pressed(btn_down) then
    settings.palette_i = (settings.palette_i - 2) % #palettes + 1
    resolve_palette(settings.palette_i)
    dset(61, settings.palette_i)
    play_sfx(7); nudge_d = 6
  end

  if nudge_l > 0 then nudge_l -= 1 end
  if nudge_r > 0 then nudge_r -= 1 end
  if nudge_u > 0 then nudge_u -= 1 end
  if nudge_d > 0 then nudge_d -= 1 end

  if btn_pressed(btn_x) then
    init_game(sel_level)
  end
  if btn_pressed(btn_o) then
    mode = "hiscore"
  end
end

function draw_start()
  local lbl = "level "..(sel_level < 10 and " " or "")..sel_level
  local lx = 64 - #lbl * 2
  local arr_l = lx - 10
  local arr_r = lx + #lbl * 4 + 2
  print("⬅️", arr_l + (nudge_l > 0 and -2 or 0), 94, 6)
  print(lbl, lx, 94, 7)
  print("➡️", arr_r + (nudge_r > 0 and 2 or 0), 94, 6)

  local pn = palette_names[settings.palette_i]
  local ppx = 64 - #pn * 2
  print("⬆️", arr_l, 104 + (nudge_u > 0 and -2 or 0), 6)
  print(pn, ppx, 104, 5)
  print("⬇️", arr_r, 104 + (nudge_d > 0 and 2 or 0), 6)

  -- action buttons: same row near bottom
  -- ❎ start = 32px, gap 6px, 🅾️ hi scores = 48px ヌ●★ total 86px centered
  print("❎ start", 21, 119, 14)
  print("🅾️ hi scores", 59, 119, 14)
end

--> WIN

function update_win()
  if btn_pressed(btn_up) then
    win_cursor = (win_cursor - 2) % 2 + 1
    play_sfx(7)
  elseif btn_pressed(btn_down) then
    win_cursor = win_cursor % 2 + 1
    play_sfx(6)
  elseif btn_pressed(btn_x) then
    if win_cursor == 1 then
      sel_level = 1; mode = "start"
    else
      if new_hs_pos then
        ini_chars = {0,0,0}; ini_pos = 1; ini_rep_ud = 0; hs_entry_done = false
      else
        hs_entry_done = true
      end
      hs_from_gameover = true; hs_can_retry = false; mode = "hiscore"
    end
  end
end

function draw_win()
  local title = "you win!"
  print("\^w\^t"..title, 64 - #title * 4, 36, 11)
  local sc = fmt_score()
  print(sc, 64 - #sc * 2, 62, 7)
  local opts = {
    "to start",
    new_hs_pos and "enter hi score" or "hi scores",
  }
  local opt_cols = {14, new_hs_pos and 7 or 14}
  for i = 1, 2 do
    local y = 80 + (i-1) * 12
    if i == win_cursor then print(">", 36, y, opt_cols[i]) end
    print(opts[i], 46, y, opt_cols[i])
  end
end

--> GAME OVER

function update_gameover()
  if go_flash > 0 then
    go_flash -= 1
    return
  end
  if btn_pressed(btn_up) then
    go_cursor = (go_cursor - 2) % 3 + 1
    play_sfx(7)
  elseif btn_pressed(btn_down) then
    go_cursor = go_cursor % 3 + 1
    play_sfx(6)
  elseif btn_pressed(btn_x) then
    if go_cursor == 1 then
      retry_from = "gameover"; mode = "confirm_retry"
    elseif go_cursor == 2 then
      if new_hs_pos then
        ini_chars = {0,0,0}; ini_pos = 1; ini_rep_ud = 0; hs_entry_done = false
      else
        hs_entry_done = true
      end
      hs_from_gameover = true; hs_can_retry = true; mode = "hiscore"
    else
      sel_level = 1; mode = "start"
    end
  end
end

function update_confirm_retry()
  if btn_pressed(btn_x) then
    init_game(level)
  elseif btn_pressed(btn_o) then
    mode = retry_from
  end
end

function ordinal(n)
  local s = tostr(n)
  if n==1 then return s.."st"
  elseif n==2 then return s.."nd"
  elseif n==3 then return s.."rd"
  else return s.."th" end
end

function draw_confirm_retry()
  local msg = "retry level "..level.."?"
  print("\^w\^t"..msg, 64 - #msg * 4, 34, 8)
  if gameover_hs_pos then
    local l1 = "your new "..ordinal(gameover_hs_pos).." place"
    local l2 = "highscore will be lost"
    print(l1, 64 - #l1 * 2, 54, 10)
    print(l2, 64 - #l2 * 2, 62, 10)
  end
  print("x yes", 46, 76, 14)
  print("o back", 46, 86, 5)
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
      local opts = {
        "retry",
        new_hs_pos and "enter hi score" or "hi scores",
        "menu",
      }
      local opt_cols = {14, new_hs_pos and 7 or 14, 14}
      for i = 1, 3 do
        local y = 76 + (i-1) * 12
        if i == go_cursor then print(">", 36, y, opt_cols[i]) end
        print(opts[i], 46, y, opt_cols[i])
      end
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
        alive = true,
        has_heart = false,
        has_pu = false
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
    new_hs_pos = hs_check(score_hi, score_lo)
    gameover_hs_pos = new_hs_pos
    win_cursor = 1
    mode = "win"
    return
  end
  apply_level(level)
  assign_hearts()
  assign_powerup_brick()
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
  lives_start = 2
  lives_lost_in_level = 0
  heart_can_spawn = false
  hearts = {}
  score_hi = 0
  score_lo = 0
  bark_msg = ""; bark_t = 0; bark_exit_t = 0
  paddle_passthrough = false
  ball_in_score = false
  go_flash = 0
  new_hs_pos = nil
  gameover_hs_pos = nil
  particles = {}
  volley = 0
  plean = 0
  poff = 0
  bump_rise_t = 0
  bump_grace_t = 0
  serve_idle_t = 0
  wall_sfx_t = 0
  traj_phase = 0
  serving = true
  clear_delay = 0
  falling_pus = {}
  pu_type = 0
  big_t = 0
  split_t = 0
  heavy_t = 0
  has_rocket = false
  rocket_held = false
  rocket_active = false
  has_portal = false
  apply_level(level)
  assign_hearts()
  assign_powerup_brick()
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

  pw = big_t > 0 and 36 or 24
  if big_t   > 0 then big_t   -= 1 end
  if split_t > 0 then split_t -= 1 end
  if heavy_t > 0 then heavy_t -= 1 end

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

  local at_wall = (btn_held(btn_left) and px == 0) or (btn_held(btn_right) and px == 128 - pw)
  if at_wall then
    if wall_sfx_t == 0 then play_sfx(11); wall_sfx_t = 15 end
    wall_sfx_t -= 1
  else
    wall_sfx_t = 0
  end

  -- tick bump and cooldown timers
  if pbump > 0 then pbump -= 1 end
  if bump_cd > 0 then bump_cd -= 1 end

  -- press fires bump and kicks paddle up; holding after settles into depressed
  if not serving then
    if btn_pressed(btn_x) and bump_cd == 0 then
      do_bump()
      bump_rise_t = 6
    end
    if bump_rise_t > 0 then
      pyo = -2
      bump_rise_t -= 1
      if bump_rise_t == 0 then bump_grace_t = 1 end
    elseif bump_grace_t > 0 then
      bump_grace_t -= 1
      pyo = 0
    elseif btn_held(btn_x) then
      pyo = 1
    else
      pyo = 0
    end
  end

  -- ball follows paddle until served
  if serving then
    bx = px + pw / 2
    by = py + pyo - br
    traj_phase += sqrt((plean*1.5*bump_mult)^2 + (1.5*bump_mult)^2) * 0.35
    serve_idle_t += 1
    if serve_idle_t == 300 then
      fire_bark("x serve", 14, 9999, 1, 100)
    end
    if btn_pressed(btn_x) then
      do_bump()
      play_sfx(2)
      local shine = {{7,5},{7,6},{5,6}}
      for i = 1, 6 do
        local a = rnd(1)
        local s = 0.5 + rnd(0.9)
        local pair = shine[flr(rnd(3))+1]
        spawn_particle(bx, by, cos(a)*s, sin(a)*s-0.2,
                       16+flr(rnd(12)), pair[1], pair[2], 0, 1)
      end
      bdx = (plean * 1.5 + rnd(0.6) - 0.3) * bump_mult
      bdy = -1.5 * bump_mult
      if has_rocket then has_rocket = false; rocket_active = true end
      serving = false
      bump_rise_t = 6
      paddle_passthrough = true
      serve_idle_t = 0
      cancel_bark()
      volley = 0
    end
    return
  end

  -- rocket held: ball sticks to paddle, player re-aims and fires
  if rocket_held then
    bx = px + pw / 2
    by = py + pyo - br
    if btn_pressed(btn_x) then
      rocket_held = false
      rocket_active = true
      bdx = plean * 1.5 * bump_mult
      bdy = -1.5 * bump_mult
      paddle_passthrough = true
      cancel_bark()
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
    rocket_active = false
    play_sfx(0)
  end
  if bx + br > 127 then
    bx = 127 - br
    bdx = -bdx
    rocket_active = false
    play_sfx(0)
  end
  if by - br < 0 then
    by = br
    bdy = -bdy
    rocket_active = false
    play_sfx(0)
  end

  -- split paddle collision (above main paddle, no bump mechanics)
  if split_t > 0 and not paddle_passthrough then
    local spy  = py + pyo - 14
    local spx_l = px + flr((pw - 14) / 2) + poff
    local spx_r = spx_l + 14
    local s_crossed = pby + br <= spy and by + br >= spy
    local s_in_x = bx + br >= spx_l and bx - br <= spx_r
    if s_crossed and s_in_x then
      by = spy - br
      bdy = -abs(bdy)
      play_sfx(5)
    end
  end

  -- effective paddle top accounts for bump offset
  local hext = (bump_rise_t==5 or bump_rise_t==3 or bump_rise_t==2) and 1 or 0
  local epy = py + pyo - hext

  local hx_l = px + min(0, poff)
  local hx_r = px + pw + max(0, poff)
  local in_x = bx + br >= hx_l and bx - br <= hx_r

  -- swept top-face check: use prev_pyo for "was above" so pyo changes don't open gaps
  local crossed_top = pby + br <= py + prev_pyo and by + br >= epy

  if not paddle_passthrough then
    if crossed_top and in_x then
      by = epy - br
      if has_rocket then
        has_rocket = false
        rocket_held = true
        bdx = 0; bdy = 0
      else
      bdy = -abs(bdy)
      local hit = (bx - px) / pw
      local angle_bdx = (hit - 0.5) * 4
      bdx = bdx * 0.5 + angle_bdx * 0.2 + pdx * 0.5
      local is_sweet = bump_rise_t >= 2
      local is_grace = bump_rise_t == 1 or bump_grace_t > 0
      if is_sweet then
        -- sweet spot: full boost + bark
        bdx = mid(-max_spd, bdx * bump_mult, max_spd)
        bdy = mid(-max_spd, bdy * bump_mult, -0.5)
        local was_perfect = bump_rise_t >= 4
        bump_rise_t = 0; bump_grace_t = 0
        play_sfx(2)
        volley = 0
        local shine = {{7,5},{7,6},{5,6}}
        for i = 1, 6 do
          local a = rnd(1); local s = 0.5 + rnd(0.9)
          local pair = shine[flr(rnd(3))+1]
          spawn_particle(bx, by, cos(a)*s, sin(a)*s-0.2,
                         16+flr(rnd(12)), pair[1], pair[2], 0, 1)
        end
        if was_perfect then fire_bark("Bump!", 11, 22, 1, py - 10) end
      elseif is_grace then
        -- grace: sfx + particles, no bark, no velocity change
        bump_rise_t = 0; bump_grace_t = 0
        play_sfx(2)
        volley = 0
        local shine = {{7,5},{7,6},{5,6}}
        for i = 1, 6 do
          local a = rnd(1); local s = 0.5 + rnd(0.9)
          local pair = shine[flr(rnd(3))+1]
          spawn_particle(bx, by, cos(a)*s, sin(a)*s-0.2,
                         16+flr(rnd(12)), pair[1], pair[2], 0, 1)
        end
      elseif btn_held(btn_x) then
        -- depressed: slow the ball down
        local spd = sqrt(bdx*bdx + bdy*bdy)
        local slow = max(min_spd, spd * 0.2)
        bdx = bdx / spd * slow * 0.5
        bdy = -slow
        play_sfx(14)
        volley = 0
      else
        bdy = max(-max_spd, bdy * 1.08)
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
      end  -- end has_rocket else
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

  -- bottom collision
  if by + br > 127 then
    if has_portal then
      has_portal = false
      by = br
      bdy = -abs(bdy)
      fire_bark("portal!", 11, 60, 1, 64)
      play_sfx(10)
    elseif lives > 0 then
      by = 127 - br
      bdy = -abs(bdy)
      bdx = flr(bdx / 2)
      bdy = flr(bdy / 2)
      if abs(bdy) < min_spd then bdy = -min_spd end
      lives -= 1
      lives_lost_in_level += 1
      heart_can_spawn = true
      fire_bark("-1♥", 8, 90, -1)
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
      gameover_hs_pos = new_hs_pos
      local taunt = lose_phrases[flr(rnd(#lose_phrases))+1]
      fire_bark(taunt, 8, 90, -1)
      go_flash = 145
      go_cursor = 1
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
        if b.has_heart and lives < lives_start then
          spawn_heart(b.x + bw/2, b.y)
        end
        if b.has_pu then
          spawn_falling_pu(b.x + bw/2, b.y, pu_type)
        end
        volley += 1
        if volley >= 2 then fire_bark(streak_bark(volley), 11, 120) end
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
        local spd = sqrt(bdx*bdx + bdy*bdy)
        local bmult = spd < max_spd * 0.4 and 1.02 or 1
        if rocket_active then
          -- punch through: no deflection
        elseif heavy_t > 0 then
          -- heavy: vertical deflect only, punch through horizontally
          if was_above or was_below then
            bdy = mid(-max_spd, -bdy * bmult, max_spd)
          end
        elseif was_above or was_below then
          bdy = mid(-max_spd, -bdy * bmult, max_spd)
        else
          bdx = mid(-max_spd, -bdx * bmult, max_spd)
        end
        add_score()
        play_sfx(3)
        if all_cleared() then clear_delay = 15 end
      end
    end
  end
end

function update_transition()
  pw = big_t > 0 and 36 or 24
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
    if btn_pressed(btn_x) and bump_cd == 0 then
      do_bump()
      bump_rise_t = 6
    end
    if bump_rise_t > 0 then
      pyo = -2
      bump_rise_t -= 1
      if bump_rise_t == 0 then bump_grace_t = 1 end
    elseif bump_grace_t > 0 then
      bump_grace_t -= 1
      pyo = 0
    elseif btn_held(btn_x) then
      pyo = 1
    else
      pyo = 0
    end
  end

  if serving or rocket_held then
    bx = px + pw / 2
    by = py + pyo - br
  end
  traj_phase += (serving and 1.95 or sqrt(bdx*bdx + bdy*bdy)) * 0.35
  trans_timer -= 1
  if serving then
    if     trans_timer == 149 then play_sfx(12)
    elseif trans_timer == 90  then play_sfx(13)
    end
    if trans_timer <= 75 then mode = "game" end
  else
    if     trans_timer == 120 then play_sfx(12)
    elseif trans_timer == 90  then play_sfx(12)
    elseif trans_timer == 60  then play_sfx(12)
    elseif trans_timer == 30  then play_sfx(13)
    end
    if trans_timer <= 0 then mode = "game" end
  end
end

pu_labels = {"b","s","r","h","p"}
pu_dur = 600

function assign_powerup_brick()
  local pool = {}
  for b in all(bricks) do
    if not b.has_heart then add(pool, b) end
  end
  if #pool == 0 then
    for b in all(bricks) do add(pool, b) end
  end
  if #pool > 0 then
    local brick = pool[flr(rnd(#pool)) + 1]
    brick.has_pu = true
    pu_type = flr(rnd(5)) + 1
  end
end

function spawn_falling_pu(x, y, ptype)
  local hw = bw >= 14 and 4 or bw >= 4 and 3 or bw >= 2 and 2 or 1
  add(falling_pus, {x=x, y=y, dy=0.5, ptype=ptype, hw=hw, hh=5})
end

function update_falling_pus()
  for i = #falling_pus, 1, -1 do
    local p = falling_pus[i]
    p.y += p.dy
    local in_x = p.x - p.hw <= px + pw and p.x + p.hw >= px
    local in_y = p.y + p.hh >= py + pyo and p.y <= py + pyo + ph
    if in_x and in_y then
      activate_powerup(p.ptype)
      deli(falling_pus, i)
    elseif p.y > 130 then
      deli(falling_pus, i)
    end
  end
end

function activate_powerup(ptype)
  if     ptype == 1 then big_t   = pu_dur
  elseif ptype == 2 then split_t = pu_dur
  elseif ptype == 3 then has_rocket = true
  elseif ptype == 4 then heavy_t = pu_dur
  elseif ptype == 5 then has_portal = true
  end
  fire_bark("+"..pu_labels[ptype].."!", 11, 60, 1, py - 12)
  play_sfx(10)
end

function draw_falling_pus()
  for p in all(falling_pus) do
    print(pu_labels[p.ptype], p.x - 2, p.y, 11)
  end
end

function assign_hearts()
  if heart_can_spawn then
    for b in all(bricks) do
      if rnd(100) < 1 then b.has_heart = true end
    end
  end
  if lives_lost_in_level > 0 and lives < lives_start then
    local pool = {}
    for b in all(bricks) do add(pool, b) end
    if #pool > 0 then
      pool[flr(rnd(#pool)) + 1].has_heart = true
    end
  end
  lives_lost_in_level = 0
end

function spawn_heart(x, y)
  local hw = bw >= 14 and 4 or bw >= 4 and 3 or bw >= 2 and 2 or 1
  local hh = bw >= 14 and 11 or bw >= 4 and 5 or bw >= 2 and 5 or 1
  add(hearts, {x=x, y=y, dy=0.5, bw=bw, hw=hw, hh=hh})
end

function update_hearts()
  for i = #hearts, 1, -1 do
    local h = hearts[i]
    h.y += h.dy
    local in_x = h.x - h.hw <= px + pw and h.x + h.hw >= px
    local in_y = h.y + h.hh >= py + pyo and h.y <= py + pyo + ph
    if in_x and in_y then
      if lives < lives_start then
        lives += 1
        fire_bark("+1♥", 8, 60, 1, py - 10)
        play_sfx(10)
      end
      deli(hearts, i)
    elseif h.y > 130 then
      deli(hearts, i)
    end
  end
end

function draw_hearts()
  for h in all(hearts) do
    if h.bw >= 14 then
      print("\^w\^t♥", h.x - 4, h.y, 8)
    elseif h.bw >= 4 then
      print("\^w♥", h.x - 4, h.y, 8)
    elseif h.bw >= 2 then
      print("♥", h.x - 2, h.y, 8)
    else
      pset(h.x, h.y, 8)
    end
  end
end

function draw_trajectory()
  local tdx, tdy
  local is_free_aim = serving or rocket_held
  if is_free_aim then
    tdx = plean * 1.5 * bump_mult
    tdy = -1.5 * bump_mult
  else
    tdx, tdy = bdx, bdy
  end
  local spd = sqrt(tdx*tdx + tdy*tdy)
  local t = mid(0, 1, (spd - min_spd) / (max_spd - min_spd))
  local dot_every = max(1, flr((1 - t) * 7) + 1)
  local offset = is_free_aim and 0 or flr(traj_phase) % dot_every
  local tx, ty = bx, by
  local prev_tx, prev_ty = tx, ty
  local bounces = 0
  local post_bounce = 0
  local max_bounces = 1
  local max_post    = is_free_aim and 40 or 999
  for i = 1, 200 do
    prev_tx, prev_ty = tx, ty
    tx += tdx
    ty += tdy
    if tx - br < 0   then tx = br;      tdx = abs(tdx);  bounces += 1 end
    if tx + br > 127 then tx = 127-br;  tdx = -abs(tdx); bounces += 1 end
    if ty - br < 0   then ty = br;      tdy = abs(tdy);  bounces += 1 end
    if not rocket_held then
      for _, b in ipairs(bricks) do
        if b.alive and tx+br > b.x and tx-br < b.x+bw
                   and ty+br > b.y and ty-br < b.y+bh then
          if prev_ty+br <= b.y or prev_ty-br >= b.y+bh then
            tdy = -tdy
          else
            tdx = -tdx
          end
          bounces += 1
          break
        end
      end
    end
    if bounces > 0 then post_bounce += 1 end
    if ty > py or bounces > max_bounces or post_bounce > max_post then break end
    if (i - offset + dot_every) % dot_every == 0 then pset(tx, ty, 7) end
  end
end

function draw_transition()
  draw_game()
  draw_trajectory()
  local msg, col
  if serving then
    if trans_timer > 90 then
      msg = "level "..level
      col = 13
    else
      msg = "go!"
      col = 7
    end
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
      local cx = b.x + flr(bw/2)
      local cy = b.y
      if b.has_heart and heart_can_spawn then
        if bw >= 4 then print("♥", cx-2, cy, 8)
        else pset(cx, cy+flr(bh/2), 8) end
      end
      if b.has_pu then
        local lbl = pu_labels[pu_type]
        if bw >= 4 then print(lbl, cx-2, cy, 11)
        else pset(cx, cy+flr(bh/2), 11) end
      end
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

--> BARKS

lose_phrases = {
  "skill issue.",
  "woof...",
  "embarrassing...",
  "hesitation is defeat",
  "oops",
}

streak_phrases = {
  {2,  "double!"},
  {3,  "triple!"},
  {4,  "quad!"},
  {5,  "cinco!"},
  {6,  "hail satan!"},
  {7,  "lucky!"},
  {8,  "wild!"},
  {9,  "nein!"},
  {10, "on a roll!"},
  {25, "on fire!"},
  {50, "wtf!?"},
}

function streak_bark(n)
  local label = ""
  for _, p in ipairs(streak_phrases) do
    if n >= p[1] then label = p[2] end
  end
  return label.." ("..n..")"
end

function cancel_bark()
  bark_t = 0; bark_exit_t = 0; bark_enter_t = 0
end

function fire_bark(msg, col, t, dir, y)
  bark_msg = msg
  bark_col = col or 7
  bark_t = t or 40
  bark_exit_t = 0
  bark_enter_t = 8
  bark_dir = dir or 1
  bark_amp = dir == -1 and 2 or 1
  bark_y = y or 56
end

function update_bark()
  if bark_enter_t > 0 then
    bark_enter_t -= 1
  elseif bark_t > 0 then
    bark_t -= 1
    if bark_t == 0 then bark_exit_t = 10 end
  elseif bark_exit_t > 0 then
    bark_exit_t -= 1
  end
end

function draw_bark()
  if bark_enter_t == 0 and bark_t == 0 and bark_exit_t == 0 then return end
  local x = 64 - #bark_msg * 2
  local y = bark_y
  if bark_enter_t > 0 then
    y += bark_enter_t * bark_dir * bark_amp
  elseif bark_exit_t > 0 then
    y -= (10 - bark_exit_t) * bark_dir * bark_amp
  end
  print(bark_msg, x+1, y+1, 0)
  print(bark_msg, x, y, bark_col)
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
  if hs_from_gameover and new_hs_pos and not hs_entry_done then
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
    if mud == -1 then play_sfx(6) elseif mud == 1 then play_sfx(7) end
    if btn_pressed(btn_x) then
      if ini_pos < 3 then
        ini_pos += 1; play_sfx(6)
      else
        hs_insert(new_hs_pos,score_hi,score_lo,level,ini_chars[1],ini_chars[2],ini_chars[3])
        play_sfx(10)
        new_hs_pos = nil
        hs_entry_done = true
      end
    elseif btn_pressed(btn_o) then
      if ini_pos > 1 then
        ini_pos -= 1; play_sfx(7)
      else
        mode = hs_can_retry and "gameover" or "win"
        play_sfx(7)
      end
    end
  else
    if btn_pressed(btn_x) then
      if hs_can_retry then
        retry_from = "hiscore"
        mode = "confirm_retry"
      else
        hs_from_gameover = false; sel_level = 1; mode = "start"
      end
    elseif btn_pressed(btn_o) then
      hs_from_gameover = false; hs_can_retry = false
      sel_level = 1; mode = "start"
    end
  end
end

function draw_hiscore()
  local showing_entry = hs_from_gameover and new_hs_pos and not hs_entry_done
  print("high scores", 64-11*2, 2, 10)
  local list_y = 13
  local list_n = hs_max
  if showing_entry then
    print("new best!", 64-9*2, 11, 10)
    local ex = 46
    for i = 1, 3 do
      local col = i < ini_pos and 11 or i == ini_pos and 7 or 5
      print("\^w\^t"..ini_chr(ini_chars[i]), ex+(i-1)*14, 19, col)
      if i == ini_pos then line(ex+(i-1)*14, 34, ex+(i-1)*14+7, 34, 7) end
    end
    local prompt = ini_pos < 3 and "x next" or "x submit"
    print(prompt, 64-#prompt*2, 38, 14)
    print("o skip", 64-6*2, 38, 14)
    line(0, 46, 127, 46, 5)
    list_y = 49
    list_n = 6
  end
  for i = 1, list_n do
    local e = hs[i]
    local y = list_y+(i-1)*10
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
  if not showing_entry then
    if hs_can_retry then
      print("x retry  o menu", 64-15*2, 118, 14)
    elseif hs_from_gameover then
      print("x to start  o menu", 64-18*2, 118, 14)
    else
      print("❎ / 🅾️ menu", 50, 118, 14)
    end
  end
end

function draw_game()
  draw_particles()
  draw_bricks()
  draw_hud()
  -- drop shadows
  local sdy = (bump_rise_t >= 2) and 2 or 1
  rectfill(px+1+poff, py+sdy, px+pw+1+poff, py+ph+sdy, 0)
  circfill(bx+1, by+1, br, 0)
  -- afterimage extends the trail visually
  if not serving then
    circfill(pbx, pby, br, 1)
  end
  -- split paddle
  if split_t > 0 then
    local spy = py + pyo - 14
    local spx = px + flr((pw - 14) / 2) + poff
    rectfill(spx+1, spy+1, spx+15, spy+ph+1, 0)
    rectfill(spx, spy, spx+14, spy+ph, 13)
  end
  -- paddle and ball
  rectfill(px+poff, py+pyo, px+pw+poff, py+pyo+ph, 13)
  circfill(bx, by, br, 13)
  -- shine
  pset(bx-1, by-1, 7)
  if serving or rocket_held then draw_trajectory() end
  draw_hearts()
  draw_falling_pus()
  draw_bark()
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
000100000e6100301004010070100a0200d02010020150101a0102001026010007000000022000220000000000000210002100000000000001e0001f000000000000000000190001800000000000000000000000
00010000000000331006310097100c7200b7200972007710057100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0001000019020130200e020050302100021000200001e0001b0001900017000130001100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000504006010060200603006030060200001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400002801000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000400001f01000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000704008040090400b0300c0300d0300f030100301302016020190201b0201e01024010290102d01035010000000000000000000000000000000000000000000000000000000000000000000000000000
000200001a4102041024410286102d6103361034610336102f6102a61027610226101f6101f6101e6101d6101c6101a6201862013410134101241011410104200f4100d4100b4200941008410064100441000420
0003000014610146101461019600302002c6102c6102f2103721039200382003d2003f20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000087000772006720067300673006720047200471006f00000003b7003b7003b7003b7003b7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000500000451004500045100450000500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00050000000000b5100b5100b51000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000c5100c520060200502004020010300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 50424344

