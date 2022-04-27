# frozen_string_literal: true

class PicRenderer
  def self.white
    @white ||= ChunkyPNG::Color.from_hex(COLORS[15])
  end

  def self.red
    @red ||= ChunkyPNG::Color.from_hex(COLORS[4])
  end

  def initialize(cmds)
    @pic_target = ChunkyPNG::Image.new(X_SIZE, Y_SIZE, PicRenderer.white)
    @pri_target = ChunkyPNG::Image.new(X_SIZE, Y_SIZE, PicRenderer.red)

    @draw_pic = true
    @draw_pri = false

    @cmds = cmds
    @ip = 0
    @pic_color = ChunkyPNG::Color.rgba(0, 0, 0, 0)
    @x = 0
    @y = 0
  end

  def nib(n)
    (n & 0b0111) * (n & 0b1000 == 0b1000 ? -1 : 1)
  end

  def not_cmd?
    @cmds[@ip] < 0xf0
  end

  def render
    while @ip < @cmds.size
      case @cmds[@ip]
      when CMDS[:pic_color]
        @pic_color = ChunkyPNG::Color.from_hex(COLORS[@cmds[@ip + 1]])
        @draw_pic = true
        @ip += 2
      when CMDS[:disable_pic]
        @draw_pic = false
        @ip += 1
      when CMDS[:pri_color]
        @pri_color = ChunkyPNG::Color.from_hex(COLORS[@cmds[@ip + 1]])
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
          fill(@cmds[@ip], @cmds[@ip + 1])
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

  def pset(x, y)
    return if x < 0 || y < 0 || x >= X_SIZE || y >= Y_SIZE
    @pic_target[x, y] = @pic_color if @draw_pic
    @pri_target[x, y] = @pri_color if @draw_pri
  end

  # Thanks: https://wiki.scummvm.org/index.php?title=AGI/Specifications/Pic
  def draw_line(x1, y1, x2, y2)
    height = y2 - y1
    width = x2 - x1
    addX = height == 0 ? height : width.to_f / height.abs
    addY = width == 0 ? width : height.to_f / width.abs

    if width.abs > height.abs
      x = x1
      y = y1
      addX = width == 0 ? 0 : (width / width.abs)
      while x != x2
        pset(sierra_round(x, addX), sierra_round(y, addY))
        x += addX
        y += addY
      end
      pset(x2, y2)
    else
      x = x1
      y = y1
      addY = height == 0 ? 0 : (height / height.abs)
      while y != y2
        pset(sierra_round(x, addX), sierra_round(y, addY))
        x += addX
        y += addY
      end
      pset(x2, y2)
    end
  end

  def fill(x, y)
    queue = [[x, y]]
    while !queue.empty?
      x, y = queue.pop

      if @draw_pic
        pic_val = @pic_target[x, y]
        next if @pic_color != PicRenderer.white && pic_val != PicRenderer.white
        next if @pic_color == PicRenderer.white && pic_val == PicRenderer.white
        @pic_target[x, y] = @pic_color
        queue << [x - 1, y] if x > 0
        queue << [x + 1, y] if x < X_SIZE - 1
        queue << [x, y - 1] if y > 0
        queue << [x, y + 1] if y < Y_SIZE - 1
      end

      if @draw_pri
        pri_val = @pri_target[x, y]
        @pri_target[x, y] = @pri_color
        next if pri_val != PicRenderer.red

        queue << [x - 1, y] if x > 0
        queue << [x + 1, y] if x < X_SIZE - 1
        queue << [x, y - 1] if y > 0
        queue << [x, y + 1] if y < Y_SIZE - 1
      end

    end
  end

  def line_to(x, y)
    draw_line(@x, @y, x, y)
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

  def write(output_width: 160)
    output = @pic_target.dup
    ratio = Y_SIZE.to_f / X_SIZE.to_f
    output.resample_nearest_neighbor!(
      output_width,
      (output_width * 0.5 * ratio).round
    ) if output_width != 160
    output.save("tmp.png")
    # @pri_target.save("tmp.pri.png")
  end

end
