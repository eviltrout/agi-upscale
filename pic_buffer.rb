# frozen_string_literal: true

class PicBuffer
  attr_accessor :width, :height

  def initialize(width, height, default = 0)
    @width, @height = width, height

    @data = []
    @height.times { @data << Array.new(@width, default) }
  end

  def []=(x, y, color)
    return if x < 0 || y < 0 || x > @width - 1 || y > @height - 1
    @data[y][x] = color
  end

  def [](x, y)
    @data[y][x]
  end

  def to_magick
    result = Magick::Image.new(@width, @height)
    result.store_pixels(
      0,
      0,
      @width,
      @height,
      @data.flatten.map { |p| IM_COLORS[p] }
    )
    result
  end
end
