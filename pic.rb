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

if ARGV.size != 3
  puts "Usage: #{$0} <game directory> <pic id> <outfile>"
  puts "  Example: #{$0} kq2 1 room1.png"
  puts
  puts "To export all pics:"
  puts "  #{$0} kq2 all output_dir"
  exit
end

loader = PicLoader.new(ARGV[0])
loader.setup

if ARGV[1] == 'all'
  puts "Exporting all pics"
  loader.db.keys.each do |id|
    puts "Exporting #{id}..."
    renderer = PicRenderer.new(loader.load(id))
    renderer.upscale(1600)
    renderer.render
    fn = "#{ARGV[2]}/#{id}.png"
    renderer.write(fn, width: 1600)
    puts "Created #{fn}"
  end
else
  renderer = PicRenderer.new(loader.load((ARGV[1] || '1').to_i))
  renderer.upscale(1600)
  renderer.render
  renderer.write(ARGV[2], width: 1600)
end
