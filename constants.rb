# frozen_string_literal: true

X_SIZE = 160
Y_SIZE = 168

CMDS = {
  pic_color: 0xf0,
  disable_pic: 0xf1,
  pri_color: 0xf2,
  disable_pri: 0xf3,
  y_corner: 0xf4,
  x_corner: 0xf5,
  abs_line: 0xf6,
  rel_line: 0xf7,
  fill: 0xf8,
  brush_style: 0xf9,
  brush_draw: 0xfa,
  end: 0xff
}

COLORS = {
  0 => "#000000",
  1 => "#0000aa",
  2 => "#00aa00",
  3 => "#00aaaa",
  4 => "#aa0000",
  5 => "#aa00aa",
  6 => "#aa5500",
  7 => "#aaaaaa",
  8 => "#555555",
  9 => "#5555ff",
  10 => "#55ff55",
  11 => "#55ffff",
  12 => "#ff5555",
  13 => "#ff55ff",
  14 => "#ffff55",
  15 => "#ffffff"
}

IM_COLORS = {}
COLORS.each do |k, v|
  IM_COLORS[k] = Magick::Pixel.from_color(v)
end
