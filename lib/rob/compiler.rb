module Rob
  class CompiledLabel
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def to_s
      name.to_s
    end
  end

  class CompiledProcedure
    attr_reader :args, :code, :name

    def initialize(args, code, name='')
      @args = args
      @code = code
      @name = name
    end

    def to_s(indent=0)
      s = ''
      prefix = ' ' * nesting

      s << prefix + "----------\n"
      s << prefix + "Proc: #{name}"
      s << prefix + "Args: #{args}\n"

      code.each do |instr|
        name, opcode, arg = instr.name, instr.opcode, instr.arg
        if instr.is_a?(CompiledLabel)
          s << prefix + "  #{name}:\n"
        else
          s << prefix + sprintf("    %-12s", VM.opcode2str(opcode))
          if arg.nil?
            s << "\n"
          elsif opcode == VM::OP_FUNCTION
            s << "\n"
            s << arg.to_s(nesting + 8)
          else
            arg_s = scheme_expr?(arg) ? expr_to_s(arg) : arg.to_s
            s << "#{arg_s}\n"
          end
        end
      end

      s << "----------\n"
      s
    end
  end

  class Compiler
    include ExprFunctions

    def initialize
      @label_id = 0
    end

    def compile(exprs)
      compiled_exprs = comp_exprlist(exprs)
      CompiledProcedure.new([], compiled_exprs)
    end

    def make_label(prefix=nil)
      prefix ||= 'LABEL'
      @label_id += 1
      CompiledLabel.new("#{prefix}#{@label_id}")
    end

    def instr(opcode, arg=nil)
      [VM::Instruction.new(opcode, arg)]
    end

    def instr_seq(*args)
      args.flatten
    end

    def comp(expr)
      case
      when self_evaluating?(expr)
        instr(VM::OP_CONST, expr)
      when variable?(expr)
        instr(VM::OP_LOADVAR, expr)
      when quoted?(expr)
        instr(VM::OP_CONST, text_of_quotation(expr))
      when assignment?(expr)
        comp_assignment(expr)
      when definition?(expr)
        comp_definition(expr)
      when if?(expr)
        comp_if(expr)
      when cond?(expr)
        comp(convert_cond_to_ifs(expr))
      when let?(expr)
        comp(convert_let_to_application(expr))
      when lambda?(expr)
        comp_lambda(expr)
      when begin?(expr)
        comp_begin(begin_actions(expr))
      when application?(expr)
        comp_application(expr)
      else
        raise CompileError.new("Unknown expression in compile: #{expr}")
      end
    end
      
    def comp_assignment(expr)
      instr_seq(
        comp(assignment_value(expr)),
        instr(VM::OP_STOREVAR, assignment_variable(expr))
      )
    end
      
    def comp_lambda(expr)
      args = expand_nested_pairs(lambda_parameters(expr))
      arglist = []
      args.each do |sym|
        if sym.is_a?(Symbol)
          arglist << sym.value
        else
          raise CompileError.new("Expected symbol in argument list, got: #{expr_to_s(sym)}")
        end
      end
        
      fn_code = instr_seq(
        comp_begin(lambda_body(expr)),
        instr(VM::OP_RETURN)
      )
        
      instr(VM::OP_FUNCTION, CompiledProcedure.new(argslist, fn_code))
    end
      
    def comp_begin(exprs)
      comp_exprlist(expand_nested_pairs(exprs, false))
    end
      
    def comp_exprlist(exprlist)
      instr_pairs = exprlist.map do |expr|
        [instr_seq(comp(expr)), instr(VM::OP_POP)]
      end
      instrs = instr_seq(*instr_pairs)
      instrs.length > 0 ? instrs[0...-1] : instrs
    end
      
    def comp_definition(expr)
      compiled_val = comp(definition_value(expr))
      var = definition_value(expr)
      # If the value is a procedure (a lambda), assign its .name attribute
      # to the variable name (for debugging)
      last = compiled_val[-1]
      if last.is_a?(Instruction) && last.arg.is_a?(CompiledProcedure)
        last.arg.name = var.value
      end

      instr_seq(compiled_val, instr(VM::OP_DEFVAR, var))
    end

    def comp_if(expr)
      label_else = make_label
      label_after_else = make_label
        
      instr_seq(
        comp(if_predicate(expr)),
        instr(VM::OP_FJUMP, label_else),
        comp(if_consequent(expr)),
        instr(VM::OP_JUMP, label_after_else),
        [label_else],
        comp(if_alternative(expr)),
        [label_after_else]
      )
    end

    def comp_application(expr)
      args = expand_nested_pairs(application_operands(expr), false)
      compiled_args = instr_seq(*args.map {|x| comp(x)})
      compiled_op = comp(application_operator(expr))
      instr_seq(
        compiled_args,
        compiled_op,
        instr(VM::OP_CALL, args.length)
      )
    end
  end

  class Assembler
    def assemble(fn)
      label_offsets = compute_label_offsets(fn)
      assemble_to_code(fn, label_offsets)
    end

    def compute_label_offsets(fn)
      d = {}
      offset = 0
        
      fn.code.each do |instr|
        if instr.is_a?(CompiledLabel)
          d[instr.name] = offset
        else
          offset += 1
        end
      end

      d
    end

    def assemble_to_code(fn, label_offsets)
      c = VM::CodeObject.new
      c.name = fn.name
      c.args = fn.args

      fn.code.each do |instr|
        next if instr.is_a?(CompiledLabel)

        case instr.opcode
        when VM::OP_CONST
          if instr.is_a?(Pair)
            c.constants << instr.arg
            arg = c.constants.length - 1
          else
            arg = list_find_or_append(c.constants, instr.arg)
          end
        when VM::OP_LOADVAR, VM::OP_STOREVAR, VM::OP_DEFVAR
          arg = list_find_or_append(c.varnames, instr.arg.value)
        when VM::OP_FUNCTION
          c.constants << assemble(instr.arg)
          arg = c.constants.length - 1
        when VM::OP_FJUMP, VM::OP_JUMP
          arg = label_offsets[instr.arg.name]
        when VM::OP_CALL
          arg = instr.arg
        when VM::OP_POP, VM::OP_RETURN
          arg = nil
        else
          raise CompileError.new("Unexpected opcode #{instr.opcode} in assemble")
        end
        c.code << VM::Instruction.new(instr.opcode, arg)
      end
      c
    end

    #If item is in the list, return its index. Otherwise, append it to the 
    #list and return its index.
    #
    #Note: may modify the list
    def list_find_or_append(list, item)
      idx = list.index(item)
      if idx
        return idx
      else
        list << item
        return list.length - 1
      end
    end
  end
end

