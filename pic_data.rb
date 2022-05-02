# frozen_string_literal: true

class PicData

  attr_reader :cmds
  attr_accessor :compressed

  def initialize(cmds)
    @cmds = cmds.unpack('C*')
    @compressed = false
    @ip = 0
  end

  def compressed?
    @compressed
  end

  def next_byte
    result = @cmds[@ip]
    @ip += 1
    result
  end

  def next_word
    [next_byte, next_byte]
  end

  def not_cmd?
    @cmds[@ip] < 0xf0
  end

  def has_more?
    @ip < @cmds.size
  end

end
