module Rob
  class Error < StandardError; end
end

require 'rob/expr'
require 'rob/lexer'
require 'rob/parser'
require 'rob/builtins'
require 'rob/env'
require 'rob/interpreter'
require 'rob/bytecode_serializer'
require 'rob/vm'
require 'rob/compiler'

module Rob
  def self.parse(str)
    Parser.new.parse(str)
  end

  def self.interpret(str, output=nil)
    exprs = Parser.new.parse(str)
    interp = Interpreter.new(output)
    exprs.each { |e| interp.interpret(e) }
  end

  def self.compile(str)
    parsed_exprs = parse(str)
    compiled = Compiler.new.compile(parsed_exprs)
    Assembler.new.assemble(compiled)
  end

  def self.repl
    interp = Interpreter.new
    parser = Parser.new
    puts "Rob REPL. Type a scheme expression or 'quit'"
    loop do
      print "[rob] :>"
      input = gets.chomp
      break if input == 'quit'
      exprs = parser.parse(input)
      val = interp.interpret(exprs[0])
      next if val.nil?
      if val.is_a?(Procedure)
        print ": <procedure>"
      else
        print ":", expr_to_s(val)
      end
    end
  end
end
