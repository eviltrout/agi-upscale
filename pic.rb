# frozen_string_literal: true

require 'rubygems'
require 'bundler'

Bundler.require(:default)

X_SIZE = 160
Y_SIZE = 168
OUTPUT_WIDTH = 1000

require './constants'
require './helpers'
require './pic_loader'
require './pic_renderer'

loader = PicLoader.new('kq2')
loader.setup

cmds = loader.load((ARGV[0] || '1').to_i)
renderer = PicRenderer.new(cmds)
renderer.render
renderer.write

# puts "cmds size: #{cmds.size}"
# puts "png size: #{File.size("tmp.png")}"
