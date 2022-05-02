# frozen_string_literal: true

require 'rubygems'
require 'bundler'

Bundler.require(:default)

require './constants'
require './helpers'
require './pic_buffer'
require './pic_data'
require './pic_path'
require './pic_loader'
require './pic_renderer'

if ARGV.size != 2
  puts "Usage: #{$0} <game directory> <pic id>"
  puts "Example: #{$0} kq2 1"
  exit
end

loader = PicLoader.new(ARGV[0])
loader.setup
renderer = PicRenderer.new(loader.load((ARGV[1] || '1').to_i))
renderer.upscale(1600)
renderer.render
renderer.write("up.png", width: 1600)

# (0..255).each do |id|
#   fn = "hd/#{id.to_s.rjust(3, "0")}.png"
#   puts "doing #{id} -> #{fn}"
#   cmds = loader.load(id.to_i)
#   if cmds
#     renderer = PicRenderer.new(cmds)
#     renderer.upscale(1600)
#     renderer.render
#     renderer.write(fn, width: 1600)
#   end
# end
