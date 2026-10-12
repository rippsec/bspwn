require 'cairo'
require 'cairo_xlib'

-- Dell Precision 7780 (1920x1080): the conky window is taller than on the ThinkPad, so the
-- box is centred on the window and nudged down by block_dy to hug clock + date + calendar.
local block_dy = 18
local block_h = 485
local width   = 490
local radius  = 12
local color   = {0, 0, 0, 0.60}

function conky_draw_bg()
  if conky_window == nil then return end
  local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
    conky_window.visual, conky_window.width, conky_window.height)
  local cr = cairo_create(cs)

  local x = (conky_window.width - width) / 2
  local block_y = (conky_window.height - block_h) / 2 + block_dy

  cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
  cairo_new_sub_path(cr)
  cairo_arc(cr, x + width - radius, block_y + radius,            radius, -math.pi/2, 0)
  cairo_arc(cr, x + width - radius, block_y + block_h - radius,  radius, 0, math.pi/2)
  cairo_arc(cr, x + radius,         block_y + block_h - radius,  radius, math.pi/2, math.pi)
  cairo_arc(cr, x + radius,         block_y + radius,            radius, math.pi, 3*math.pi/2)
  cairo_close_path(cr)
  cairo_fill(cr)

  cairo_destroy(cr)
  cairo_surface_destroy(cs)
end
