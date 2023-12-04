class CommandImpl
  def self.command_name
    raise 'Command unimplemented'
  end

  def self.type_match?(argument_types)
    argument_types in []
  end

  def self.exec(ctx, arguments)
    ctx.interpreter_raise "Unimplemented command"
  end
end
