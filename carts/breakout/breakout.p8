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

pw = 24  -- paddle width
ph = 3   -- paddle height
br = 2   -- ball radius

-- resets all game state, called when starting a new game
function init_game()
  px = 64 - pw / 2
  py = 116
  bx = 64
  by = 115
  bdx = 0
  bdy = 0
  pbx = bx
  pby = by
end

function update_game()
  -- move paddle
  if btn_held(btn_left) then
    px = max(0, px - 2)
  end
  if btn_held(btn_right) then
    px = min(128 - pw, px + 2)
  end

  -- store previous ball position before moving
  pbx = bx
  pby = by

  bx += bdx
  by += bdy

  -- wall bounces
  if bx - br < 0 then
    bx = br
    bdx = -bdx
  end
  if bx + br > 127 then
    bx = 127 - br
    bdx = -bdx
  end
  if by - br < 0 then
    by = br
    bdy = -bdy
  end

  -- paddle collision using previous position to determine approach face
  local in_x = bx + br >= px and bx - br <= px + pw
  local in_y = by + br >= py and by - br <= py + ph

  if in_x and in_y then
    local was_above = pby + br <= py  -- ball approached from above
    local was_outside_x = pbx + br < px or pbx - br > px + pw  -- ball approached from side

    if was_above then
      by = py - br
      bdy = -abs(bdy)
      -- offset angle based on where ball hit along paddle width
      local hit = (bx - px) / pw  -- 0..1
      bdx = (hit - 0.5) * 4
    elseif was_outside_x then
      bdx = -bdx
    end
  end

  -- ball lost
  if by - br > 128 then
    mode = "gameover"
  end
end

function draw_game()
  rectfill(px, py, px + pw, py + ph, 7)
  circfill(bx, by, br, 7)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
