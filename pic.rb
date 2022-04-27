# frozen_string_literal: true

require 'rubygems'
require 'bundler'

Bundler.require(:default)

require './constants'
require './helpers'
require './pic_path'
require './pic_loader'
require './pic_renderer'

loader = PicLoader.new('kq2')
loader.setup

cmds = loader.load((ARGV[0] || '1').to_i)
renderer = PicRenderer.new(cmds)
renderer.render
renderer.write(width: 1000)
renderer.write_vector(width: 1000)

# puts "id,cmds_size,col_size,pri_size"
# loader.db.keys.each do |id|
#   cmds = loader.load(id)
#   renderer = PicRenderer.new(cmds)
#   renderer.render
#   renderer.write
#
#   %x{optipng tmp.png -quiet -o7}
#   %x{optipng tmp.pri.png -quiet -o7}
#   col_size = File.size("tmp.png")
#   pri_size = File.size("tmp.pri.png")
#
#   puts "#{id},#{cmds.size},#{col_size},#{pri_size}"
# end
