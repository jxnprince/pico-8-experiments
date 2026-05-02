pico-8 cartridge // http://www.pico-8.com
version 43

__lua__
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


function play_sfx(id)
  sfx(id)
end


function play_music(id)
  music(id)
end


-->8

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


function btn_held(b)
  return input.held[b]
end


function btn_pressed(b)
  return input.pressed[b]
end


-->8


function update_start()
  if btn_pressed(btn_x) then
    init_game()
    mode = "game"
  end
end


function draw_start()
  -- print("breakout", 44, 50, 7)
  print("❎ start", 46, 70, 14)
end


-->8


function update_gameover()
  if btn_pressed(btn_x) then
    mode = "start"
  end
end


function draw_gameover()
  print("game over", 42, 55, 9)
  print("❎ to restart", 36, 70, 14)
end


-->8


pw = 24  -- paddle width
ph = 3   -- paddle height
br = 2   -- ball radius


function init_game()
  px = 64 - pw / 2
  py = 116
  bx = 64
  by = 108
  bdx = 1.5
  bdy = -1.5
end


function update_game()
  if btn_held(btn_left) then
    px = max(0, px - 2)
  end
  if btn_held(btn_right) then
    px = min(128 - pw, px + 2)
  end

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

  -- paddle collision
  if by + br >= py and by + br <= py + ph + abs(bdy)
  and bx + br >= px and bx - br <= px + pw then
    by = py - br
    bdy = -abs(bdy)
    local hit = (bx - px) / pw  -- 0..1, affects bounce angle
    bdx = (hit - 0.5) * 4
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
