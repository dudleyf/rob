module Rob
  DEBUG = false

  class Procedure
    attr_reader :args, :body, :env

    def initialize(args, body, env)
      @args = args
      @body = body
      @env = env
    end
  end

  class InterpreterError < Error; end

  class Interpreter
    include ExprFunctions

    def initialize(output=nil)
      @global_env = create_global_env
      @output = output || STDOUT
    end

    def interpret(expr, env=@global_env)
      #debug "**** interpret called on #{expr_to_s(expr)} [#{expr.class}]"
      #debug "Env:\n#{env.binding}"

      if self_evaluating?(expr)
        return expr
      elsif variable?(expr)
        return env.lookup_var(expr.value)
      elsif quoted?(expr)
        return text_of_quotation(expr)
      elsif assignment?(expr)
        var = assignment_variable(expr).value
        val = interpret(definition_value(expr), env)
        return env.set_var_value(var, val)
      elsif definition?(expr)
        var = definition_variable(expr).value
        val = interpret(definition_value(expr), env)
        env.define_var(var, val)
        return nil
      elsif if?(expr)
        predicate = interpret(if_predicate(expr), env)
        if predicate == Boolean.new(false)
          return interpret(if_alternative(expr), env)
        else
          return interpret(if_consequent(expr), env)
        end
      elsif cond?(expr)
        return interpret(convert_cond_to_ifs(expr), env)
      elsif let?(expr)
        return interpret(convert_let_to_application(expr), env)
      elsif lambda?(expr)
        args = lambda_parameters(expr)
        body = lambda_body(expr)
        return Procedure.new(args, body, env)
      elsif begin?(expr)
        return interpret_sequence(begin_actions(expr), env)
      elsif application?(expr)
        op = interpret(application_operator(expr), env)
        operands = list_of_values(application_operands(expr), env)
        return apply(op, operands)
      else
        raise InterpreterError.new "Unknown expression in interpret: #{expr}"
      end
    end

    def interpret_sequence(exprs, env)
      first_val = interpret(first_expr(exprs), env)
      if last_expr?(exprs)
        first_val
      else
        interpret_sequence(rest_exprs(exprs), env)
      end
    end

    def list_of_values(exprs, env)
      if has_no_operands?(exprs)
        nil
      else
        first = interpret(first_operand(exprs), env)
        rest = list_of_values(rest_operands(exprs), env)
        Pair.new(first, rest)
      end
    end

    def apply(fn, args)
      debug "***** Applying procedure #{fn}"
      debug "      with args #{expr_to_s(args)}"

      case fn
      when BuiltinProcedure
        debug "***** Applying builtin procedure #{fn.name}"
        fn.apply(expand_nested_pairs(args))
      when Procedure
        debug "***** Applying procedure with args: #{fn.args}"
        debug "      and body:\n#{expr_to_s(fn.body)}"

        env = extend_env_for_procedure(fn.env, fn.args, args)
        interpret_sequence fn.body, env
      else
        raise InterpreterError.new "Unknown procedure type in apply: #{fn}"
      end
    end

    def extend_env_for_procedure(env, args, args_vals)
      new_bindings = {}
      while !args.nil?
        raise InterpreterError.new "Unassigned parameter in procedure call: #{args.first}" if args_vals.nil?
        new_bindings[args.first.value] = args_vals.first
        args = args.second
        args_vals = args_vals.second
      end
      Env.new(new_bindings, env)
    end

    def write_fn
      @write_fn ||= lambda { |args|
        @output.puts expr_to_s(args[0])
        nil
      }
    end

    def create_global_env
      global_binding = {}
      Builtins.each do |name, fn|
        global_binding[name] = BuiltinProcedure.new(name, fn)
      end
      global_binding['write'] = BuiltinProcedure.new('write', write_fn)
      Env.new(global_binding)
    end

    def debug(msg)
      puts msg if DEBUG
    end
  end
end
