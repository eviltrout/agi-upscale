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

    @paths = []
    @fills = []
    @draw_pic = true
    @draw_pri = false

    @current_path = nil
    @cmds = cmds
    @ip = 0
    @pic_color = 0
    @x = 0
    @y = 0
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
    @pic_target[x, y] = ChunkyPNG::Color.from_hex(COLORS[@pic_color]) if @draw_pic
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

    bitmap = []
    Y_SIZE.times { bitmap << Array.new(X_SIZE, 0) }

    while !queue.empty?
      x, y = queue.pop

      if @draw_pic
        bitmap[y][x] = 1
        pic_val = @pic_target[x, y]
        next if @pic_color != PicRenderer.white && pic_val != PicRenderer.white
        next if @pic_color == PicRenderer.white && pic_val == PicRenderer.white

        @pic_target[x, y] = ChunkyPNG::Color.from_hex(COLORS[@pic_color])
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

    @fills << [@pic_color, bitmap] if @draw_pic
  end

  def line_to(x, y)
    start_path if @draw_pic && @current_path.nil?

    draw_line(@x, @y, x, y)
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
    output = @pic_target.dup
    output.resample_nearest_neighbor!(width, height_for(width)) if width != 160
    output.save("tmp.png")
  end

  def write_vector(width: 1000)
    x_scale = width.to_f / X_SIZE.to_f
    y_scale = height_for(width).to_f / Y_SIZE.to_f

    svg = Victor::SVG.new width: width, height: height_for(width), style: { background: '#fff' }

    paths, fills = @paths, @fills

    svg.build do
      defs do
        filter(id: 'bg-blur', x: 0, y: 0) do
          svg.element 'feGaussianBlur', in: 'SourceGraphic', stdDeviation: 4
        end
      end

      COLORS.each do |id, col|
        css[".c-#{id} rect"] = { fill: col, stroke_width: 0 }
        css[".c-#{id} polygon"] = { fill: col, stroke_width: 0 }
        css[".c-#{id} line"] = { stroke: col, stroke_width: y_scale }
      end

      fills.each do |fill|
        color, bitmap = fill

        g(class: "c-#{color}", no_filter: 'url(#bg-blur)') do
          (1...Y_SIZE - 1).each do |y|
            (1...X_SIZE - 1).each do |x|
              next if bitmap[y][x] == 0

              mask =
                bitmap[y - 1][x] +
                (2 * bitmap[y][x + 1]) +
                (4 * bitmap[y + 1][x]) +
                (8 * bitmap[y][x - 1])

              x0 = (x * x_scale).floor
              x1 = x0 + (x_scale / 2.0)
              x2 = (x0 + x_scale).ceil
              y0 = (y * y_scale).floor
              y1 = y0 + (y_scale / 2.0)
              y2 = (y0 + y_scale).ceil

              case mask
              when 1
                polygon(points: "#{x0},#{y0} #{x2},#{y0} #{x1},#{y1}")
              when 2
                polygon(points: "#{x2},#{y0} #{x2},#{y2} #{x1},#{y1}")
              when 3
                polygon(points: "#{x0},#{y0} #{x2},#{y0} #{x2},#{y2}")
              when 4
                polygon(points: "#{x1},#{y1} #{x2},#{y2} #{x0},#{y2}")
              when 5
                polygon(points: "#{x0},#{y0} #{x2},#{y0} #{x1},#{y1}")
                polygon(points: "#{x1},#{y1} #{x2},#{y2} #{x0},#{y2}")
              when 6
                polygon(points: "#{x2},#{y0} #{x2},#{y2} #{x0},#{y2}")
              when 7
                polygon(points: "#{x0},#{y0} #{x2},#{y0} #{x2},#{y2} #{x0},#{y2} #{x1},#{y1}")
              when 8
                polygon(points: "#{x0},#{y0} #{x1},#{y1} #{x0},#{y2}")
              when 9
                polygon(points: "#{x0},#{y0} #{x2},#{y0} #{x0},#{y2}")
              when 10
                polygon(points: "#{x0},#{y0} #{x1},#{y1} #{x0},#{y2}")
                polygon(points: "#{x2},#{y0} #{x2},#{y2} #{x1},#{y1}")
              when 11
                polygon(points: "#{x0},#{y0} #{x2},#{y0} #{x2},#{y2} #{x1},#{y1} #{x0},#{y2}")
              when 12
                polygon(points: "#{x0},#{y0} #{x2},#{y2} #{x0},#{y2}")
              when 13
                polygon(points: "#{x0},#{y0} #{x2},#{y0} #{x1},#{y1} #{x2},#{y2} #{x0},#{y2}")
              when 14
                polygon(points: "#{x0},#{y0} #{x1},#{y1} #{x2},#{y0} #{x2},#{y2} #{x0},#{y2}")
              when 15
                polygon(points: "#{x0},#{y0} #{x2},#{y0} #{x2},#{y2} #{x0},#{y2}")
              end

            end
          end
        end
      end

      paths.each do |path|
        prev = path.points[0]
        g(class: "c-#{path.color}") do
          (1...path.points.size).each do |idx|
            p = path.points[idx]

            line(
              x1: (prev[0] * x_scale),
              y1: (prev[1] * y_scale),
              x2: (p[0] * x_scale),
              y2: (p[1] * y_scale)
            )
            prev = p
          end
        end
      end
    end

    svg.save("vec.svg")
  end

end
