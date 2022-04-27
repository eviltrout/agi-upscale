# frozen_string_literal: true

class PicPath
  attr_reader :points, :color

  def initialize(color, x, y)
    @color = color
    @points = [[x, y]]
  end

  def add_point(x, y)
    @points << [x, y]
  end
end
