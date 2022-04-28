# frozen_string_literal: true

class PicRenderer

  def initialize(cmds)
    @pic_target = Magick::Image.new(X_SIZE, Y_SIZE) do |img|
      img.background_color = IM_COLORS[15]
    end
    @pri_target = Magick::Image.new(X_SIZE, Y_SIZE) do |img|
      img.background_color = IM_COLORS[4]
    end

    @paths = []
    @draw_pic = true
    @draw_pri = false

    @current_path = nil
    @cmds = cmds
    @ip = 0
    @pic_color = 0
    @x = 0
    @y = 0
  end

  def upscaling?
    !@upscale_w.nil?
  end

  def upscale_x(x)
    (x * @upscale_sx).round
  end

  def upscale_y(y)
    (y * @upscale_sy).round
  end

  def upscale(width)
    @upscale_w = width
    @upscale_h = height_for(width)
    @upscale_sx = width.to_f / X_SIZE.to_f
    @upscale_sy = @upscale_h.to_f / Y_SIZE.to_f

    @up_target = Magick::Image.new(@upscale_w, @upscale_h) do |img|
      img.background_color = IM_COLORS[15]
    end
  end

  def nib(n)
    (n & 0b0111) * (n & 0b1000 == 0b1000 ? -1 : 1)
  end

  def not_cmd?
    @cmds[@ip] < 0xf0
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
    while @ip < @cmds.size
      end_path
      case @cmds[@ip]
      when CMDS[:pic_color]
        @pic_color = @cmds[@ip + 1]
        @draw_pic = true
        @ip += 2
      when CMDS[:disable_pic]
        @draw_pic = false
        @ip += 1
      when CMDS[:pri_color]
        @pri_color = @cmds[@ip + 1]
        @draw_pri = true
        @ip += 2
      when CMDS[:disable_pri]
        @draw_pri = false
        @ip += 1
      when CMDS[:y_corner]
        @x = @cmds[@ip + 1]
        @y = @cmds[@ip + 2]
        @ip += 3
        draw_corner(:y)
      when CMDS[:x_corner]
        @x = @cmds[@ip + 1]
        @y = @cmds[@ip + 2]
        @ip += 3
        draw_corner(:x)
      when CMDS[:abs_line]
        @x = @cmds[@ip + 1]
        @y = @cmds[@ip + 2]
        @ip += 3
        while not_cmd?
          nx = @cmds[@ip]
          ny = @cmds[@ip + 1]
          line_to(nx, ny)
          @ip += 2
        end
      when CMDS[:rel_line]
        @x = @cmds[@ip + 1]
        @y = @cmds[@ip + 2]
        @ip += 3

        pset(@x, @y)
        if upscaling? && !not_cmd?
          sz = @upscale_sy * 0.5
          gc = Magick::Draw.new
          gc.stroke_width(0)
          gc.fill(COLORS[@pic_color])
          gc.circle(upscale_x(@x), upscale_y(@y), upscale_x(@x) - sz, upscale_y(@y))
          gc.draw(@up_target)
        end

        while not_cmd?
          nx = @cmds[@ip] >> 4
          nx = (nx & 0b0111) * (nx & 0b1000 == 0b1000 ? -1 : 1)
          ny = @cmds[@ip] & 0b00001111
          ny = (ny & 0b0111) * (ny & 0b1000 == 0b1000 ? -1 : 1)
          line_to(@x + nx, @y + ny)
          @ip += 1
        end
      when CMDS[:fill]
        @ip += 1
        while not_cmd?
          bitmap = fill(@cmds[@ip], @cmds[@ip + 1])
          upscale_fill(bitmap, @cmds[@ip], @cmds[@ip + 1])
          @ip += 2
        end
      when CMDS[:end]
        return
      else
        puts "unrecognized cmd: #{cmd.to_s(16)}"
        @ip += 1
      end
    end
  end

  def pset(x, y, target = :default)
    return if x < 0 || y < 0
    if @draw_pic
      buffer = target == :upscaled ? @up_target : @pic_target
      return if x >= buffer.columns || y >= buffer.rows
      buffer.pixel_color(x, y, IM_COLORS[@pic_color])
    end
    return if x >= @pri_target.columns || y >= @pri_target.rows
    @pri_target.pixel_color(x, y, IM_COLORS[@pri_color]) if @draw_pri
  end

  # Thanks: https://wiki.scummvm.org/index.php?title=AGI/Specifications/Pic
  def draw_line(x1, y1, x2, y2, target = :default)
    height = y2 - y1
    width = x2 - x1
    addX = height == 0 ? height : width.to_f / height.abs
    addY = width == 0 ? width : height.to_f / width.abs

    if width.abs > height.abs
      x = x1
      y = y1
      addX = width == 0 ? 0 : (width / width.abs)
      while x != x2
        pset(sierra_round(x, addX), sierra_round(y, addY), target)
        x += addX
        y += addY
      end
      pset(x2, y2, target)
    else
      x = x1
      y = y1
      addY = height == 0 ? 0 : (height / height.abs)
      while y != y2
        pset(sierra_round(x, addX), sierra_round(y, addY), target)
        x += addX
        y += addY
      end
      pset(x2, y2, target)
    end
  end

  def upscale_fill(bitmap, x, y)
    return unless upscaling? && @draw_pic

    queue = [ [upscale_x(x), upscale_y(y)] ]
    while !queue.empty?
      x, y = queue.pop

      fx = (x.to_f / @upscale_sx)
      fy = (y.to_f / @upscale_sy)
      next if fx.ceil >= X_SIZE || fy.ceil >= Y_SIZE

      dx = fx.round
      dy = fy.round

      next if bitmap[dy][dx] == 0

      pic_val = @up_target.pixel_color(x, y)
      next if @pic_color != 15 && pic_val != IM_COLORS[15]
      next if @pic_color == 15 && pic_val == IM_COLORS[15]

      @up_target.pixel_color(x, y, IM_COLORS[@pic_color])
      queue << [x - 1, y] if x > 0
      queue << [x + 1, y] if x < @up_target.columns - 1
      queue << [x, y - 1] if y > 0
      queue << [x, y + 1] if y < @up_target.rows - 1
    end
  end

  def fill(x, y)
    queue = [[x, y]]

    bitmap = []
    Y_SIZE.times { bitmap << Array.new(X_SIZE, 0) }

    while !queue.empty?
      x, y = queue.pop

      if @draw_pic
        bitmap[y][x] = 1
        pic_val = @pic_target.pixel_color(x, y)
        next if @pic_color != 15 && pic_val != IM_COLORS[15]
        next if @pic_color == 15 && pic_val == IM_COLORS[15]

        @pic_target.pixel_color(x, y, IM_COLORS[@pic_color])
        queue << [x - 1, y] if x > 0
        queue << [x + 1, y] if x < @pic_target.columns - 1
        queue << [x, y - 1] if y > 0
        queue << [x, y + 1] if y < @pic_target.rows - 1
      end

      if @draw_pri
        pri_val = @pri_target.pixel_color(x, y)
        @pri_target.pixel_color(x, y, IM_COLORS[@pri_color])
        next if pri_val != IM_COLORS[4]

        queue << [x - 1, y] if x > 0
        queue << [x + 1, y] if x < @pri_target.columns - 1
        queue << [x, y - 1] if y > 0
        queue << [x, y + 1] if y < @pri_target.rows - 1
      end
    end

    bitmap
  end

  def line_to(x, y)
    start_path if @draw_pic && @current_path.nil?

    draw_line(@x, @y, x, y)

    if upscaling?
      draw_line(upscale_x(@x), upscale_y(@y), upscale_x(x), upscale_y(y), :upscaled)
    end

    @current_path.add_point(x, y) if @draw_pic
    @x = x
    @y = y
  end

  def draw_corner(direction)
    cmd = @cmds[@ip]
    if not_cmd?
      if direction == :x
        line_to(cmd, @y)
        @ip += 1
        draw_corner(:y)
      else
        line_to(@x, cmd)
        @ip += 1
        draw_corner(:x)
      end
    end
  end

  def height_for(width)
    ratio = Y_SIZE.to_f / X_SIZE.to_f
    (width * 0.5 * ratio).round
  end

  def write(width: 160)
    @pic_target.sample!(width, height_for(width)) if width != 160
    @pic_target.write("tmp.png")

    if upscaling?
      gc = Magick::Draw.new
      gc.stroke_linejoin('round')
      gc.stroke_width(@upscale_sy)
      gc.fill_opacity(0)

      @paths.each do |path|
        gc.stroke(COLORS[path.color])
        scaled = path.points.map { |p| [upscale_x(p[0]), upscale_y(p[1])] }.flatten
        gc.polyline(*scaled)
      end
      gc.draw(@up_target)
      @up_target.write("up.png")
    end
  end

end
