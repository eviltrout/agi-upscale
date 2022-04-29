# frozen_string_literal: true

require 'rubygems'
require 'bundler'

Bundler.require(:default)

require './constants'
require './helpers'
require './pic_buffer'
require './pic_path'
require './pic_loader'
require './pic_renderer'

loader = PicLoader.new('kq2')
loader.setup

cmds = loader.load((ARGV[0] || '1').to_i)
renderer = PicRenderer.new(cmds)
renderer.upscale(1000)
renderer.render
renderer.write(width: 1000)
# renderer.write_vector(width: 1000)

