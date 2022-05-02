# frozen_string_literal: true

require 'set'

class PicRenderer

  def initialize(data)
    @pic_target = PicBuffer.new(X_SIZE, Y_SIZE, 15)
    @pri_target = PicBuffer.new(X_SIZE, Y_SIZE, 4)

    @paths = []
    @dots = []
    @draw_pic = true
    @draw_pri = false
    @brush = 0x10
    @texture = 0

    @current_path = nil
    @data = data
    @pic_color = 0
    @x = 0
    @y = 0
  end

  def upscaling?
    !@upscale_w.nil?
  end

  def upscale_x(x)
    (x.to_f * @upscale_sx).round
  end

  def upscale_y(y)
    (y.to_f * @upscale_sy).round
  end

  def upscale(width)
    @upscale_w = width
    @upscale_h = height_for(width)
    @upscale_sx = width.to_f / X_SIZE.to_f
    @upscale_sy = @upscale_h.to_f / Y_SIZE.to_f

    @up_target = PicBuffer.new(@upscale_w, @upscale_h, 15)
  end

  def end_path
    @paths << @current_path if @current_path
    @current_path = nil
  end

  def start_path
    end_path
    @current_path = PicPath.new(@pic_color, @x, @y)
  end

  def render
    return if @data.nil?

    while @data.has_more?
      end_path
      cmd = @data.next_byte

      case cmd
      when CMDS[:pic_color]
        @pic_color = @data.compressed? ? @data.next_nibble : @data.next_byte
        @draw_pic = true
      when CMDS[:disable_pic]
        @draw_pic = false
      when CMDS[:pri_color]
        @pri_color = @data.compressed? ? @data.next_nibble : @data.next_byte
        @draw_pri = true
      when CMDS[:disable_pri]
        @draw_pri = false
      when CMDS[:y_corner]
        @x, @y = @data.next_word
        draw_corner(:y)
      when CMDS[:x_corner]
        @x, @y = @data.next_word
        draw_corner(:x)
      when CMDS[:abs_line]
        @x, @y = @data.next_word
        while @data.not_cmd?
          nx, ny = @data.next_word
          line_to(nx, ny)
        end
      when CMDS[:rel_line]
        @x, @y = @data.next_word
        pset(@x, @y)
        @dots << [@x, @y, @pic_color] if upscaling? && !@data.not_cmd?

        while @data.not_cmd?
          b = @data.next_byte
          nx = b >> 4
          nx = (nx & 0b0111) * (nx & 0b1000 == 0b1000 ? -1 : 1)
          ny = b & 0b00001111
          ny = (ny & 0b0111) * (ny & 0b1000 == 0b1000 ? -1 : 1)
          line_to(@x + nx, @y + ny)
        end
      when CMDS[:fill]
        while @data.not_cmd?
          fx, fy = @data.next_word
          bitmap = fill(fx, fy)
          upscale_fill(bitmap, fx, fy)
        end
      when CMDS[:brush_style]
        @brush = @data.next_byte
      when CMDS[:brush_draw]
        plot
      when CMDS[:end]
        return
      else
        puts "unrecognized cmd: #{cmd.to_s(16)}"
        exit
      end
    end
  end

  # Ported from ScummVM
  def pattern(x, y)
    pen_width = 0
    pen_final_x = 0
    pen_final_y = 0
    t = 0

    pen_x = x
    pen_y = y

    pen_size = (@brush & 0x07)
    circle_ptr = CIRCLE_PAT[pen_size]

    pen_x = (pen_x * 2) - pen_size
    pen_x = 0 if pen_x < 0

    temp16 = (X_SIZE * 2) - (2 * pen_size)
    pen_x = temp16 if pen_x >= temp16

    pen_x /= 2
    pen_final_x = pen_x

    pen_y = pen_y - pen_size
    pen_y = 0 if pen_y < 0

    temp16 = (Y_SIZE - 1) - (2 * pen_size)
    pen_y = temp16 if pen_y >= temp16
    pen_final_y = pen_y

    t = (@texture | 0x01) & 0xFF
    temp16 = (pen_size << 1) + 1
    pen_final_y += temp16
    temp16 = temp16 << 1
    pen_width = temp16

    circleCond = ((@brush & 0x10) != 0)
    counterStep = 4
    ditherCond = 0x02

    while pen_y < pen_final_y
      circle_word = CIRCLE_DATA[circle_ptr]
      circle_ptr += 1

      counter = 0
      while counter <= pen_width
        if (circleCond || ((BINARY_PAT[counter >> 1] & circle_word) != 0))
          if @brush & 0x20 != 0
            temp8 = t % 2
            t = t >> 1
            t = t ^ 0xB8 if temp8 != 0
          end

          if ((@brush & 0x20) == 0 || (t & 0x03) == ditherCond)
            pset(pen_x, pen_y)
            @dots << [pen_x, pen_y, @pic_color]
          end
        end
        pen_x += 1
        counter += counterStep
      end
      pen_x = pen_final_x
      pen_y += 1
    end

  end

  def plot
    while @data.not_cmd?
      @texture = @data.next_byte if (@brush & 0x20) == 0x20
      bx, by = @data.next_word
      pattern(bx, by)
    end
  end

  def pset(x, y, target = :default)
    return if x < 0 || y < 0
    if @draw_pic
      buffer = target == :upscaled ? @up_target : @pic_target
      buffer[x, y] = @pic_color
    end
    @pri_target[x, y] = @pri_color if @draw_pri
  end

  # Thanks: https://wiki.scummvm.org/index.php?title=AGI/Specifications/Pic
  def draw_line(x1, y1, x2, y2, target = :default)
    points = Set.new

    height = y2 - y1
    width = x2 - x1
    addX = height == 0 ? height : width.to_f / height.abs
    addY = width == 0 ? width : height.to_f / width.abs

    if width.abs > height.abs
      x = x1
      y = y1
      addX = width == 0 ? 0 : (width / width.abs)
      while x != x2
        px = sierra_round(x, addX)
        py = sierra_round(y, addY)
        points << [px, py]
        x += addX
        y += addY
      end
      points << [x2, y2]
    else
      x = x1
      y = y1
      addY = height == 0 ? 0 : (height / height.abs)
      while y != y2
        px = sierra_round(x, addX)
        py = sierra_round(y, addY)
        points << [px, py]
        x += addX
        y += addY
      end
      points << [x2, y2]
    end
    points.each { |p| pset(p[0], p[1], target) }
    points
  end

  def upscale_fill(bitmap, x, y)
    return unless upscaling? && @draw_pic

    queue = [ [upscale_x(x), upscale_y(y)] ]
    while !queue.empty?
      x, y = queue.pop

      fx = (x.to_f / @upscale_sx)
      fy = (y.to_f / @upscale_sy)
      next if fx.ceil > X_SIZE - 1 || fy.ceil > Y_SIZE - 1

      dx = fx.round
      dy = fy.round

      next if bitmap[dx, dy] == 0

      pic_val = @up_target[x, y]
      next if @pic_color != 15 && pic_val != 15
      next if @pic_color == 15 && pic_val == 15

      @up_target[x, y] = @pic_color
      queue << [x - 1, y] if x > 0
      queue << [x + 1, y] if x < @up_target.width - 1
      queue << [x, y - 1] if y > 0
      queue << [x, y + 1] if y < @up_target.height - 1
    end
  end

  def fill(x, y)
    queue = [[x, y]]

    bitmap = PicBuffer.new(X_SIZE, Y_SIZE)

    while !queue.empty?
      x, y = queue.pop

      if @draw_pic
        bitmap[x, y] = 1
        pic_val = @pic_target[x, y]
        next if @pic_color != 15 && pic_val != 15
        next if @pic_color == 15 && pic_val == 15

        @pic_target[x, y] = @pic_color
        queue << [x - 1, y] if x > 0
        queue << [x + 1, y] if x < @pic_target.width - 1
        queue << [x, y - 1] if y > 0
        queue << [x, y + 1] if y < @pic_target.height - 1
      end

      if @draw_pri
        pri_val = @pri_target[x, y]
        next if pri_val != 4
        @pri_target[x, y] = @pri_color

        queue << [x - 1, y] if x > 0
        queue << [x + 1, y] if x < @pri_target.width - 1
        queue << [x, y - 1] if y > 0
        queue << [x, y + 1] if y < @pri_target.height - 1
      end
    end

    bitmap
  end

  def find_point(x, y)
    x0, x1 = upscale_x(x - 0.5), upscale_x(x + 0.5)
    y0, y1 = upscale_y(y - 0.5), upscale_y(y + 0.5)

    (y0...y1).each do |j|
      (x0...x1).each do |i|
        return [i, j] if @up_target[i, j] != 15
      end
    end
    nil
  end

  def upscale_fix2(points, p, offset_x, offset_y)
    x0, y0 = p
    x1 = x0 + offset_x
    y1 = y0 + offset_y

    return if x1 < 0 || x1 > X_SIZE - 1 || y1 < 0 || y1 > Y_SIZE - 1
    return if points.include?([x1, y1])
    mask = @pic_target[x1, y1]

    if mask != 15
      from = [x0, y0]
      to = [x1, y1]

      start = find_point(x0, y0)
      stop = find_point(x1, y1)
      if start && stop
        draw_line(start[0], start[1], stop[0], stop[1], :upscaled)
        return true
      end
    end
    false
  end

  def line_to(x, y)
    start_path if @draw_pic && @current_path.nil?
    points = draw_line(@x, @y, x, y)

    if upscaling? && points.size > 0
      draw_line(upscale_x(@x), upscale_y(@y), upscale_x(x), upscale_y(y), :upscaled)

      points.each do |p|
        upscale_fix2(points, p, -1, -1) ||
        upscale_fix2(points, p, 0, -1) ||
        upscale_fix2(points, p, 1, -1) ||
        upscale_fix2(points, p, -1, 0) ||
        upscale_fix2(points, p, 1, 0) ||
        upscale_fix2(points, p, -1, 1) ||
        upscale_fix2(points, p, 0, 1) ||
        upscale_fix2(points, p, 1, 1)
      end
    end

    @current_path.add_point(x, y) if @draw_pic
    @x = x
    @y = y
  end

  def draw_corner(direction)
    if @data.not_cmd?
      loc = @data.next_byte
      if direction == :x
        line_to(loc, @y)
        draw_corner(:y)
      else
        line_to(@x, loc)
        draw_corner(:x)
      end
    end
  end

  def height_for(width)
    ratio = Y_SIZE.to_f / X_SIZE.to_f
    (width * 0.5 * ratio).round
  end

  def write(fn, width: 160)
    output = @pic_target.to_magick
    output.sample!(width, height_for(width)) if width != 160
    output.write("tmp.png")

    if upscaling?
      1.times do
        (1...@up_target.height - 2).each do |y|
          (1...@up_target.width - 2).each do |x|
            c0 = @up_target[x - 1, y]
            c1 = @up_target[x, y]
            c2 = @up_target[x + 1, y]

            if c0 != c1 && c1 != c2
              @up_target[x, y] = c0
            end
          end
        end
        (1...@up_target.height - 2).each do |y|
          (1...@up_target.width - 2).each do |x|
            c0 = @up_target[x, y - 1]
            c1 = @up_target[x, y]
            c2 = @up_target[x, y + 1]

            if c1 != c0 && c1 != c2
              @up_target[x, y] = c0
            end
          end
        end
      end

      up_output = @up_target.to_magick
      up_output.write("up.png")

      `convert up.png -define connected-components:verbose=true -define connected-components:area-threshold=100 -define connected-components:mean-color=true -connected-components 8 noiseless.png`

      denoised = Magick::Image.read("noiseless.png").first

      gc = Magick::Draw.new
      sz = @upscale_sy * 0.5
      @dots.each do |d|
        gc.stroke_width(0)
        gc.fill(COLORS[d[2]])
        gc.circle(upscale_x(d[0]), upscale_y(d[1]), upscale_x(d[0]) - sz, upscale_y(d[1]))
      end

      gc.stroke_linejoin('round')
      gc.stroke_width(@upscale_sy)
      gc.fill_opacity(0)

      @paths.each do |path|
        gc.stroke(COLORS[path.color])
        scaled = path.points.map { |p| [upscale_x(p[0]), upscale_y(p[1])] }.flatten
        gc.polyline(*scaled)
      end

      gc.draw(denoised)

      denoised.write(fn || "final.png")
    end
  end

end
