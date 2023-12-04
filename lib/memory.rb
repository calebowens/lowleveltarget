class Memory
  def initialize(ctx)
    @ctx = ctx
    @frames = [{}]
  end

  def get(key)
    @frames.each do |frame|
      return frame[key] if frame[key]
    end

    @ctx.interpreter_raise "Invalid reference #{key}"
  end

  def local_set(key, value)
    if value.type == :ident
      @ctx.interpreter_raise "Unable to store identifier"
    end

    @frames.first[key] = value
  end

  def set(key, value)
    if value.type == :ident
      @ctx.interpreter_raise "Unable to store identifier"
    end

    frame = @frames.find { _1[key] } || @frames.first

    frame[key] = value
  end

  def push_frame
    @frames.unshift({})
  end

  def pop_frame
    if @frames.size == 1
      @ctx.interpreter_raise "Unable to pop root frame"
    end

    @frames.shift
  end
end
