-- Cockpit HUD panel background: translucent slate card, hairline border,
-- amber corner brackets (like an instrument bezel). Palette = polybar "cockpit".
require 'cairo'
require 'cairo_xlib'

local R = 10                                   -- corner radius (matches polybar)
local BG = {0x14/255, 0x18/255, 0x20/255, 0.82}
local LINE = {0x2a/255, 0x31/255, 0x3d/255, 1}
local AMBER = {0xe8/255, 0xb0/255, 0x4b/255, 0.95}

local function rrect(cr, x, y, w, h, r)
  cairo_new_sub_path(cr)
  cairo_arc(cr, x + w - r, y + r, r, -math.pi/2, 0)
  cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi/2)
  cairo_arc(cr, x + r, y + h - r, r, math.pi/2, math.pi)
  cairo_arc(cr, x + r, y + r, r, math.pi, 3*math.pi/2)
  cairo_close_path(cr)
end

function conky_hud_bg()
  if conky_window == nil then return end
  local w, h = conky_window.width, conky_window.height
  local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
    conky_window.visual, w, h)
  local cr = cairo_create(cs)

  rrect(cr, 0.5, 0.5, w - 1, h - 1, R)
  cairo_set_source_rgba(cr, table.unpack(BG)); cairo_fill_preserve(cr)
  cairo_set_line_width(cr, 1); cairo_set_source_rgba(cr, table.unpack(LINE)); cairo_stroke(cr)

  -- amber corner brackets
  local L, o = 18, 5
  cairo_set_line_width(cr, 2); cairo_set_source_rgba(cr, table.unpack(AMBER))
  for _, c in ipairs({{o, o, 1, 1}, {w - o, o, -1, 1}, {o, h - o, 1, -1}, {w - o, h - o, -1, -1}}) do
    local x, y, sx, sy = c[1], c[2], c[3], c[4]
    cairo_move_to(cr, x, y + sy * L); cairo_line_to(cr, x, y); cairo_line_to(cr, x + sx * L, y)
    cairo_stroke(cr)
  end

  cairo_destroy(cr); cairo_surface_destroy(cs)
end
