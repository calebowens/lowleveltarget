require './lib/memory.rb'
require './lib/commands.rb'

Value = Struct.new(:type, :value) do
  def stringify
    if type == :vector
      if value.all? { _1.type == :char }
        value.map(&:value).join
      else
        '[' + value.map { _1.stringify }.join(', ') + ']'
      end
    else
      value.to_s
    end
  end
end

Command = Struct.new(:command, :arguments, :line_number, :file_name)

class Interpreter
  attr_reader :memory

  def initialize(input_file_name = 'main.weird')
    @commands = parse_file(input_file_name)
    @command_lookup = CommandImpl.subclasses.map { [_1.command_name, _1] }.to_h
    typecheck_arguments(@commands, @command_lookup)
    @label_lookup = generate_label_index(@commands)

    @memory = Memory.new(self)
    @current_command_index = @label_lookup[:main] || 0
    @jumped = false
    @traps = []
  end

  def run
    loop do
      @current_command = @commands[@current_command_index]

      if @current_command.nil?
        interpreter_exit 0
      end

      command = @command_lookup[@current_command.command]

      command.exec(self, @current_command.arguments)
      
      if @jumped
        @jumped = false
      else
        @current_command_index += 1
      end
    end
  end

  def jump(label)
    looked_up_index = @label_lookup[label]

    if looked_up_index.nil?
      interpreter_exit 1
    end

    @jumped = true
    @current_command_index = looked_up_index
  end

  def interpreter_exit(code)
    exit code
  end

  def interpreter_raise(message)
    puts "Error: #{message}\nLine #{@current_command&.line_number} file #{@current_command&.file_name}"
    exit 1
  end

  def set_trap(label, after: nil)
    @traps.push({ label:, command_index: @current_command_index + 1, after: })
  end

  def return_to_trap(label)
    @traps.drop_while { _1[:label] != label }

    ttrap = @traps.shift

    if ttrap.nil?
      interpreter_raise "Trap #{label} not found"
    end

    @current_command_index = ttrap[:command_index]
    @jumped = true

    ttrap[:after]&.call
  end

  private

  def parse_file(input_file)
    input = File.readlines(input_file, chomp: true).each_with_index.map { [_1, _2 + 1, 'main'] }

    input.each_with_index do |(line, _), index|
      if line.start_with?('!import')
        file_name = line.split(' ', 2).last

        lines = File.readlines(file_name, chomp: true)

        input[index..index] = lines.each_with_index.map { [_1, _2 + 1, file_name] }
      end
    end

    input.map do |(line, line_number, file_name)|
      next Command.new(command: :noop, arguments: [], line_number:, file_name:) if line == '' || line.start_with?('#')

      keyword, arguments = line.split(':', 2)
      arguments.strip!

      parsed_arguments = arguments&.split(',')&.map do |argument|
        argument.strip!
        sigil = argument[0]
        case sigil
        when 'i'
          Value.new(type: :i64, value: argument[1..].to_i)
        when 'f'
          Value.new(type: :f32, value: argument[1..].to_f)
        when '\''
          Value.new(type: :char, value: argument[1])
        when '"'
          Value.new(
            type: :vector,
            value: argument[1..].split('').map { Value.new(type: :char, value: _1) }
          )
        when ':'
          Value.new(
            type: :ident,
            value: argument[1..].to_sym
          )
        else
          raise "Unrecognised Identifer #{sigil} on line #{line_number} file #{file_name}"
        end
      end || []

      Command.new(
        command: keyword.strip.to_sym,
        arguments: parsed_arguments,
        line_number:,
        file_name:
      )
    end
  end

  def generate_label_index(parsed_file)
    labels = {}

    parsed_file.each_with_index do |command, index|
      if command.command == :label
        labels[command.arguments.first.value] = index
      end
    end
    
    labels
  end

  def typecheck_arguments(commands, command_index)
    commands.each do |command|
      if command_index[command.command].nil?
        raise "Command #{command.command} on line #{command.line_number} file #{command.file_name}"
      end

      unless command_index[command.command].type_match?(command.arguments.map(&:type))
        raise "Mismatched type arguments for #{command.command} on line #{command.line_number} file #{command.file_name}"
      end
    end
  end
end
