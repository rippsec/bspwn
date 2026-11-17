-- Cockpit HUD panel: translucent black card, hairline border, red corner
-- brackets (instrument bezel) + month calendar with today boxed in red.
-- Palette = polybar "cockpit" (black / white / red).
require 'cairo'
require 'cairo_xlib'

local R = 10                                   -- corner radius (matches polybar)
local BG = {0x11/255, 0x12/255, 0x14/255, 0.84}
local LINE = {0x2a/255, 0x2b/255, 0x30/255, 1}
local ACCENT = {0xe5/255, 0x38/255, 0x3b/255, 0.95}
local FG = {0xe6/255, 0xe3/255, 0xdd/255, 1}
local DIM = {0x8e/255, 0x90/255, 0x99/255, 1}
local WHITE = {0xf2/255, 0xef/255, 0xe9/255, 1}
local FONT = "Atkinson Hyperlegible Mono"

-- month calendar position inside the panel (the conky text leaves a gap here)
local CAL_Y, CELL_W, CELL_H = 112, 36, 21

local function rrect(cr, x, y, w, h, r)
  cairo_new_sub_path(cr)
  cairo_arc(cr, x + w - r, y + r, r, -math.pi/2, 0)
  cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi/2)
  cairo_arc(cr, x + r, y + h - r, r, math.pi/2, math.pi)
  cairo_arc(cr, x + r, y + r, r, math.pi, 3*math.pi/2)
  cairo_close_path(cr)
end

function draw_calendar(cr, w)
  local x0 = (w - 7 * CELL_W) / 2
  local now = os.date("*t")
  local first = os.time({year = now.year, month = now.month, day = 1, hour = 12})
  local wd = (tonumber(os.date("%w", first)) + 6) % 7          -- Monday = 0
  local days = tonumber(os.date("%d", os.time({year = now.year, month = now.month + 1, day = 0, hour = 12})))

  local function text_c(str, cx, cy, size, weight, col)
    cairo_select_font_face(cr, FONT, CAIRO_FONT_SLANT_NORMAL, weight)
    cairo_set_font_size(cr, size)
    local ext = cairo_text_extents_t:create()
    cairo_text_extents(cr, str, ext)
    cairo_set_source_rgba(cr, table.unpack(col))
    cairo_move_to(cr, cx - ext.width / 2 - ext.x_bearing, cy - ext.height / 2 - ext.y_bearing)
    cairo_show_text(cr, str)
  end

  for i, d in ipairs({"MO", "TU", "WE", "TH", "FR", "SA", "SU"}) do
    text_c(d, x0 + (i - 0.5) * CELL_W, CAL_Y, 10, CAIRO_FONT_WEIGHT_BOLD, i >= 6 and ACCENT or DIM)
  end
  for day = 1, days do
    local idx = wd + day - 1
    local col, row = idx % 7, math.floor(idx / 7)
    local cx = x0 + (col + 0.5) * CELL_W
    local cy = CAL_Y + 8 + (row + 0.5) * CELL_H + 4
    if day == now.day then
      rrect(cr, cx - 15, cy - 10, 30, 20, 5)
      cairo_set_source_rgba(cr, table.unpack(ACCENT)); cairo_fill(cr)
      text_c(tostring(day), cx, cy, 13, CAIRO_FONT_WEIGHT_BOLD, WHITE)
    else
      text_c(tostring(day), cx, cy, 12, CAIRO_FONT_WEIGHT_NORMAL, col >= 5 and DIM or FG)
    end
  end
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
  cairo_set_line_width(cr, 2); cairo_set_source_rgba(cr, table.unpack(ACCENT))
  for _, c in ipairs({{o, o, 1, 1}, {w - o, o, -1, 1}, {o, h - o, 1, -1}, {w - o, h - o, -1, -1}}) do
    local x, y, sx, sy = c[1], c[2], c[3], c[4]
    cairo_move_to(cr, x, y + sy * L); cairo_line_to(cr, x, y); cairo_line_to(cr, x + sx * L, y)
    cairo_stroke(cr)
  end

  draw_calendar(cr, w)
  cairo_destroy(cr); cairo_surface_destroy(cs)
end
