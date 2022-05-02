# frozen_string_literal: true

class PicData

  attr_reader :cmds, :ip
  attr_accessor :compressed

  def initialize(cmds)
    @cmds = cmds.unpack('C*')
    @compressed = false
    @ip = 0
    @on_nibble = false
  end

  def compressed?
    @compressed
  end

  def next_nibble
    if @on_nibble
      @on_nibble = false
      result = @cmds[@ip] & 0x0F
      @ip += 1
      return result
    end

    @on_nibble = true
    @cmds[@ip] >> 4
  end

  def next_byte
    if @on_nibble
      n_result = (@cmds[@ip] << 4) & 0xFF
      @ip += 1
      return (@cmds[@ip] >> 4) | n_result
    end

    result = @cmds[@ip]
    @ip += 1
    result
  end

  def next_word
    [next_byte, next_byte]
  end

  def not_cmd?
    val = @cmds[@ip]
    if @on_nibble
      val = (@cmds[@ip + 1] >> 4) | ((@cmds[@ip] << 4) & 0xFF)
    end

    val < 0xf0
  end

  def has_more?
    @ip < @cmds.size
  end

end
