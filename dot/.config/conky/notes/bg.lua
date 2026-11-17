require 'cairo'
require 'cairo_xlib'

-- rounded translucent panel behind the whole notes window (same look as conky/bg.lua)
local radius = 12
local color  = {0, 0, 0, 0.60}
local border = {1, 1, 1, 0.08}

function conky_draw_notes_bg()
  if conky_window == nil then return end
  local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
    conky_window.visual, conky_window.width, conky_window.height)
  local cr = cairo_create(cs)

  local x, y = 1, 1
  local w, h = conky_window.width - 2, conky_window.height - 2

  cairo_new_sub_path(cr)
  cairo_arc(cr, x + w - radius, y + radius,     radius, -math.pi/2, 0)
  cairo_arc(cr, x + w - radius, y + h - radius, radius, 0, math.pi/2)
  cairo_arc(cr, x + radius,     y + h - radius, radius, math.pi/2, math.pi)
  cairo_arc(cr, x + radius,     y + radius,     radius, math.pi, 3*math.pi/2)
  cairo_close_path(cr)

  cairo_set_source_rgba(cr, color[1], color[2], color[3], color[4])
  cairo_fill_preserve(cr)
  cairo_set_source_rgba(cr, border[1], border[2], border[3], border[4])
  cairo_set_line_width(cr, 1)
  cairo_stroke(cr)

  cairo_destroy(cr)
  cairo_surface_destroy(cs)
end
