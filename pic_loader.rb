# frozen_string_literal: true

class PicLoader
  attr_accessor :entries, :db

  def initialize(dir)
    @dir = dir
    @db = {}
  end

  def setup
    dir_file = "#{@dir}/PICDIR"

    sz = File.size(dir_file)
    @entries = sz / 3

    buf = File.open(dir_file, 'rb').read.unpack('C*')

    File.open(dir_file, 'rb') do |f|
      @entries.times do |idx|
        data = f.read(3).unpack('CS>')
        next if data[0] == 0xff && data[1] == 0xffff
        @db[idx] = { id: idx, vol: data[0] >> 4, offset: data[1] | (data[0] & 0xf) << 16 }
      end
    end
  end

  def volume_data(id, offset)
    vol_file = "#{@dir}/VOL.#{id}"
    File.open(vol_file, 'rb') do |f|
      f.seek(offset)
      header = f.read(5).unpack('S<CS<')
      return f.read(header[2]) if header[0] == 0x3412 && header[1] == id
    end
    nil
  end

  def load(id)
    pic_index = @db[id]
    return nil unless pic_index
    puts "loading #{pic_index.inspect}..."

    volume_data(pic_index[:vol], pic_index[:offset]).unpack('C*')
  end
end

