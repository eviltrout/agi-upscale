# frozen_string_literal: true

class PicLoader
  attr_accessor :entries, :db

  def initialize(dir)
    @dir = dir
    @db = {}
    @prefix = ''
    @version = 2
  end

  def setup
    dir_file = "#{@dir}/PICDIR"

    if File.exist?(dir_file)
      @version = 2
      File.open(dir_file, 'rb') { |f| load_entries(f) }
    else
      dirs = Dir["#{@dir}/*DIR"].to_a
      if dirs && dirs.size == 1
        dir = dirs[0]
        @prefix = dir.sub(@dir + '/', '')[0..-4]
        @version = 3

        File.open(dirs[0], 'rb') do |f|
          offsets = f.read(6).unpack('S<S<S<')
          load_entries(f, offsets[1], offsets[2])
        end
      else
        puts "Can't find a directory file"
        exit
      end
    end
  end

  def load_entries(file, start = 0, stop = nil)
    file.seek(start)
    stop ||= file.size
    @entries = (stop - start) / 3
    @entries.times do |idx|
      data = file.read(3).unpack('CS>')
      next if data[0] == 0xff && data[1] == 0xffff
      @db[idx] = { id: idx, vol: data[0] >> 4, offset: data[1] | (data[0] & 0xf) << 16 }
    end
  end

  def volume_data(id, offset)
    vol_file = "#{@dir}/#{@prefix}VOL.#{id}"
    File.open(vol_file, 'rb') do |f|
      f.seek(offset)
      if @version == 2
        header = f.read(5).unpack('S<CS<')
        return PicData.new(f.read(header[2])) if header[0] == 0x3412 && header[1] == id
      else
        header = f.read(7).unpack('S<CS<S<')
        return nil unless header[0] == 0x3412 &&
          (header[1] & 0x80 == 0x80) &&
          (header[1] & 0x7f == id)

        data = PicData.new(f.read(header[2]))
        data.compressed = header[2] != header[3]
        return data
      end
    end
    nil
  end

  def load(id)
    pic_index = @db[id]
    return nil unless pic_index
    volume_data(pic_index[:vol], pic_index[:offset])
  end
end
