module Rob
  class VMError < Error; end

  class VM
    OP_CONST    = 0x00
    OP_LOADVAR  = 0x10
    OP_STOREVAR = 0x11
    OP_DEFVAR   = 0x12
    OP_FUNCTION = 0x20
    OP_POP      = 0x30
    OP_JUMP     = 0x40
    OP_FJUMP    = 0x41
    OP_RETURN   = 0x50
    OP_CALL     = 0x51

    OpcodeNames = {
      OP_CONST    => 'CONST',
      OP_LOADVAR  => 'LOADVAR',
      OP_STOREVAR => 'STOREVAR',
      OP_DEFVAR   => 'DEFVAR',
      OP_FUNCTION => 'FUNCTION',
      OP_POP      => 'POP',
      OP_JUMP     => 'JUMP',
      OP_FJUMP    => 'FJUMP',
      OP_RETURN   => 'RETURN',
      OP_CALL     => 'CALL'
    }

    def self.opcode2str(opcode)
      OpcodeNames[opcode]
    end

    class Instruction
      attr_reader :opcode, :arg

      def initialize(opcode, arg)
        @opcode = opcode
        @arg = arg
      end
      
      def to_s
        "#{VM.opcode2str(opcode)} #{arg}"
      end
    end

    class CodeObject
      attr_accessor :name,
        :args,
        :code,
        :constants,
        :varnames

      def initialize
        @name = ''
        @args = []
        @code = []
        @constants = []
        @varnames = []
      end

      def to_s(nesting=0)
        s = ''
        indent = ' ' * nesting

        s << indent + "-------\n"
        s << indent + "CodeObject: #{name}\n"
        s << indent + "Args: #{args}\n"
        
        code.each_with_index do |instr, i|
          opcode, arg = instr.opcode, instr.arg

          s << indent + sprintf("  %4s %-12s", i, VM.opcode2str(instr.opcode))

          case opcode
          when OP_CONST
            s << sprintf("%4s {= %s}\n", arg, expr_to_s(constants[arg]))
          when OP_LOADVAR, OP_STOREVAR, OP_DEFVAR
            s << sprintf("%4s {= %s}\n", arg, varnames[arg])
          when OP_FJUMP, OP_JUMP
            s << sprintf("%4s\n", arg)
          when OP_CALL
            s << sprintf("%4s\n", arg)
          when OP_POP, OP_RETURN
            s << "\n"
          when OP_FUNCTION
            s << sprintf("%4s {=\n", arg)
            s << constants[arg].to_s(nesting + 8)
          else
            raise "Unexpected opcode #{opcode}"
          end
        end
        s << indent + "-------\n"
        s
      end
    end
  
    class Closure
      attr_reader :codeobject, :env

      def initialize(codeobject, env)
        @codeobj = codeobject
        @env = env
      end
    end

    class ExecutionFrame
      attr_reader :codeobject, :pc, :env

      def initialize(codeobject, pc, env)
        @codeobject = codeobject
        @pc = pc
        @env = env
      end
    end

    attr_reader :values,
      :frames
      :frame
      :output

    def initialize(output=nil)
      @values = []
      @frames = []
      @frame = ExecutionFrame.new(nil, nil, create_global_env)
      @output = output || STDOUT
    end
    
    def run(codeobject)
      frame.codeobject = codeobject
      frame.pc = 0
      
      loop do
        instr = get_next_instruction

        if instr.nil?
          if in_toplevel_code?
            break
          else
            raise VMError.new "Code object ended prematurely: #{codeobject}"
          end
        end

        opcode, arg = instr.opcode, instr.arg

        case opcode
        when OP_CONST
          values.push(frame.codeobject.constants[arg])
        when OP_LOADVAR
          value = frame.env.lookup_var(frame.codeobject.varnames[arg])
          values.push(value)
        when OP_STOREVAR
          value = values.pop
          frame.env.set_var_value(frame.codeobject.varnames[arg], value)
        when OP_DEFVAR
          value = values.pop
          frame.env.define_var(frame.codeobject.varnames[arg], value)
        when OP_POP
          values.pop if values.length > 0
        when OP_JUMP
          frame.pc = arg
        when OP_FJUMP
          predicate = values.pop
          if predicate.is_a?(Boolean) && predicate.value == false
            frame.pc = arg
          end
        when OP_FUNCTION
          fn_code = frame.codeobject.constants[arg]
          closure = Closure.new(fn_code, frame.env)
          values.push(closure)
        when OP_CALL
          # For CALL what we have on TOS the function and then the 
          # arguments to pass to it - the last argument is highest on
          # the stack.
          # The function is either a BuiltinProcedure or a Closure (for
          # user-defined procedures)
          fn = values.pop
          args = arg.map { |x| values.pop }.reverse
          
          if fn.is_a?(BuiltinProcedure)
            result = fn.apply(args)
            values.push(result)
          elsif fn.is_a?(Closure)
            if fn.codeobject.args.length != args.length
              raise VMError.new("Calling procedure #{fn.codeobject.name} with #{args.length} args, expeced #{fn.codeobject.args.length}")
            end

            # We're now going to execute a code object, so save the
            # current execution frame on the frame stack.
            frames.push(frame)

            # Extend the closure's environment with the bindings of
            # argument names --> passed values. 
            arg_bindings = {}
            fn.codeobject.args.each_with_index do |arg, i|
              arg_bindings[arg] = args[i]
            end
            extended_env = Env.new(arg_bindings, fn.env)

            # Start executing the procedure
            @frame = ExecutionFrame.new(fn.codeobject, 0, env)
          else
            raise VMError.new("Invalid object on stack for call: #{fn}")
          end
        when OP_RETURN
          @frame = frames.pop
        else
          raise VMError.new("Unknown instruction opcode: #{opcode}")
        end
      end
    end

    def get_next_instruction
      return nil if frame.pc >= frame.codeobject.code
      instr = frame.codeobject.code[frame.pc]
      frame.pc += 1
      instr
    end

    def in_toplevel_code?
      frames.length == 0
    end

    def create_global_env
      global_binding = {}
      Builtins.each do |name, fn|
        global_binding[name] = BuiltinProcedure.new(name, fn)
      end

      global_binding['write'] = BuiltinProcedure.new('write', lambda { |args|
        @output.puts expr_to_s(args[0])
        nil
      })

      global_binding['debug-vm'] = BuiltinProcedure.new('debug-vm', lambda { |args|
        puts show_vm_state
      })

      Env.new(global_binding)
    end

    def show_vm_state
      value_printer = lambda do |item|
        if item.is_a?(Closure)
          "| Closure <#{item.codeobject.name}>"
        elsif item.is_a?(BuiltinProcedure)
          "| BuiltinProcedure <#{item.name}>"
        else
          "| #{expr_to_s(item)}"
        end
      end
      
      frame_printer = lambda do |item|
        "Code: <#{item.codeobject.name}>\n [pc=#{item.pc}]"
      end
      
      show_stack = lambda do |stack, name, item_printer|
        s = ''

        head = '-' * (name.length + 8)
        s << "+#{head}+"
        s << "| #{name} stack |\n"
        s << "+#{head}+\n\n"
        
        i = 0
        while i < stack.length
          s << '      |--------\n'
          if i == 0
            s << 'TOS:  '
          else
            s << '      '
          end
          item = stack[1+i]
          s << item_printer.call(item)
          i += 1
        end
        s << '      |--------\n'
        s
      end

      s = show_stack(values, 'Value', value_printer)
      s << "\n" + show_stack(frames, 'Frame', frame_printer)
      s
    end
  end
end
