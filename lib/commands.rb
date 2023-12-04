require './lib/command_impl.rb'

class NoopImpl < CommandImpl
  def self.command_name
    :noop
  end

  def self.exec(ctx, _)
  end
end

class LabelImpl < CommandImpl
  def self.command_name
    :label
  end

  def self.type_match?(argument_types)
    argument_types in [:ident]
  end

  def self.exec(ctx, _)
  end
end

class PutImpl < CommandImpl
  def self.command_name
    :put
  end

  def self.type_match?(argument_types)
    argument_types in [:ident | :i64 | :f32 | :vector | :char]
  end

  def self.exec(ctx, (arg))
    if arg.type == :ident
      arg = ctx.memory.get(arg.value)
    end

    puts arg.stringify
  end
end

class PopFrameImpl < CommandImpl
  def self.command_name
    :popframe
  end

  def self.exec(ctx, _)
    ctx.memory.pop_frame
  end
end

class PushFrameImpl < CommandImpl
  def self.command_name
    :pushframe
  end

  def self.exec(ctx, _)
    ctx.memory.push_frame
  end
end

class SetImpl < CommandImpl
  def self.command_name
    :set
  end

  def self.type_match?(argument_types)
    argument_types in [:ident, :ident | :i64 | :f32 | :vector | :char]
  end

  def self.exec(ctx, (target, value))
    if value.type == :ident
      value = ctx.memory.get(value.value)
    end

    ctx.memory.set(target.value, value)
  end
end

class JmpImpl < CommandImpl
  def self.command_name
    :jmp
  end

  def self.type_match?(argument_types)
    argument_types in [:ident]
  end

  def self.exec(ctx, arguments)
    target = arguments.first.value

    ctx.jump(target)
  end
end

class ExitImpl < CommandImpl
  def self.command_name
    :exit
  end

  def self.exec(ctx, _)
    ctx.interpreter_exit 0
  end
end

class LocalSetImpl < CommandImpl
  def self.command_name
    :local_set
  end

  def self.type_match?(argument_types)
    argument_types in [:ident, :ident | :i64 | :f32 | :vector | :char]
  end

  def self.exec(ctx, (target, value))
    if value.type == :ident
      value = ctx.memory.get(value.value)
    end

    ctx.memory.local_set target.value, value
  end
end

class SetTrapImpl < CommandImpl
  def self.command_name
    :set_trap
  end

  def self.type_match?(argument_types)
    argument_types in [:ident]
  end

  def self.exec(ctx, (ident))
    ctx.set_trap ident.value
  end
end

class ReturnToTrapImpl < CommandImpl
  def self.command_name
    :return_to_trap
  end

  def self.type_match?(argument_types)
    argument_types in [:ident]
  end

  def self.exec(ctx, (ident))
    ctx.return_to_trap ident.value
  end
end

class TrappedJumpImpl < CommandImpl
  def self.command_name
    :trapped_jmp
  end

  def self.type_match?(argument_types)
    argument_types in [:ident]
  end

  def self.exec(ctx, (ident))
    ctx.set_trap ident.value
    ctx.jump ident.value
  end
end

class VectorPushImpl < CommandImpl
  def self.command_name
    :vec_push
  end

  def self.type_match?(argument_types)
    argument_types in [:ident, :ident | :i64 | :f32 | :vector | :char]
  end

  def self.exec(ctx, (target, value))
    if value.type == :ident
      value = ctx.memory.get(value.value)
    end

    ctx.memory.get(target.value).value.push(value)
  end
end

class EachImpl < CommandImpl
  def self.command_name
    :each
  end

  def self.type_match?(argument_types)
    argument_types in [:ident, :ident | :vector, :ident, :ident]
  end

  def self.exec(ctx, (item_name, target_vec, loop_label, excape_label))
    if target_vec.type == :ident
      target_vec = ctx.memory.get(target_vec.value)
    end

    unless target_vec.type == :vector
      interpreter_raise "Target is not a vector"
    end

    ctx.memory.push_frame
    EachTrapCallback.new(ctx, item_name, target_vec, loop_label, excape_label, 0).call
  end
end

class EachTrapCallback
  def initialize(ctx, item_name, target_vec, loop_label, excape_label, current_index)
    @ctx = ctx
    @item_name = item_name
    @target_vec = target_vec
    @loop_label = loop_label
    @excape_label = excape_label
    @current_index = current_index
  end

  def call
    if @target_vec.value.size == @current_index
      @ctx.memory.pop_frame
      @ctx.jump @excape_label.value
    else
      @ctx.memory.set @item_name.value, @target_vec.value[@current_index]
      @ctx.set_trap :each, after: EachTrapCallback.new(@ctx, @item_name, @target_vec, @loop_label, @excape_label, @current_index + 1)
      @ctx.jump @loop_label.value
    end
  end
end

class AddImpl < CommandImpl
  def self.command_name
    :add
  end

  def self.type_match?(argument_types)
    argument_types in [:ident | :i64 | :f32, :ident | :i64 | :f32, :ident]
  end

  def self.exec(ctx, (a, b, output))
    if a.type == :ident
      a = ctx.memory.get(a.value)
    end

    if b.type == :ident
      b = ctx.memory.get(b.value)
    end

    unless a.type == b.type
      ctx.interpreter_raise "Both operands must be of same type"
    end

    ctx.memory.set output.value, Value.new(type: a.type, value: a.value + b.value)
  end
end
