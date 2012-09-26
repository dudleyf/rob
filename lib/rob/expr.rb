module Rob
  class Pair
    attr_accessor :first, :second

    def initialize(first, second)
      @first = first
      @second = second
    end

    def ==(other)
      other.is_a?(Pair) &&
        first == other.first &&
        second == other.second
    end
  end

  class Atom
    attr_accessor :value

    def initialize(value)
      @value = value
    end

    def inspect
      value.to_s
    end

    def ==(other)
      if other.is_a?(self.class)
        value == other.value
      else
        value == other
      end
    end
  end

  class Number < Atom
  end

  class Symbol < Atom
  end

  class Boolean < Atom
    def inspect
      value ? '#t' : '#f'
    end

    def ==(other)
      other.is_a?(self.class) && value == other.value
    end
  end

  class ExprError < Error; end

  module ExprFunctions
    extend self

    def expr_to_s(obj)
      case obj
      when nil
        '()'
      when Boolean, Symbol, Number, Procedure, BuiltinProcedure
        obj.inspect
      when Pair
        str = '(' + expr_to_s(obj.first)
        while obj.second.is_a?(Pair)
          str += ' ' + expr_to_s(obj.second.first)
          obj = obj.second
        end
        if obj.second.nil?
          str += ')'
        else
          str += ' . ' + expr_to_s(obj.second) + ')'
        end
        return str
      else
        raise ExprError.new("Unexpected type: #{obj.class}")
      end
    end

    def make_nested_pairs(*args)
      return nil if args.length == 0
      Pair.new(args[0], make_nested_pairs(*args[1..-1]))
    end

    def expand_nested_pairs(pair, recursive=false)
      list = []
      while pair.is_a?(Pair)
        head = pair.first
        if recursive && head.is_a?(Pair)
          list << expand_nested_pairs(head)
        else
          list << head
        end
        pair = pair.second
      end
      list
    end

    def scheme_expr?(expr)
      expr.nil? ||
        self_evaluating?(expr) ||
        variable?(expr) ||
        expr.is_a?(Pair)
    end

    def self_evaluating?(expr)
      expr.is_a?(Number) || expr.is_a?(Boolean)
    end

    def variable?(expr)
      expr.is_a?(Symbol)
    end

    def tagged_list?(expr, tag)
      expr.is_a?(Pair) && expr.first == tag
    end

    def quoted?(expr)
      tagged_list? expr, 'quote'
    end

    def text_of_quotation(expr)
      expr.second.first
    end

    def assignment?(expr)
      tagged_list? expr, 'set!'
    end

    def assignment_variable(expr)
      expr.second.first
    end

    def assignment_value(expr)
      expr.second.second.first
    end

    def definition?(expr)
      tagged_list? expr, 'define'
    end

    def definition_variable(expr)
      if expr.second.first.is_a?(Symbol)
        expr.second.first
      else
        expr.second.first.first
      end
    end

    def definition_value(expr)
      if expr.second.first.is_a?(Symbol)
        expr.second.second.first
      else
        formal_params = expr.second.first.second
        body = expr.second.second
        make_lambda formal_params, body
      end
    end

    def lambda?(expr)
      tagged_list? expr, 'lambda'
    end

    def lambda_parameters(expr)
      expr.second.first
    end

    def lambda_body(expr)
      expr.second.second
    end

    def make_lambda(parameters, body)
      Pair.new Symbol.new('lambda'), Pair.new(parameters, body)
    end

    def if?(expr)
      tagged_list?(expr, 'if')
    end

    def if_predicate(expr)
      expr.second.first
    end

    def if_consequent(expr)
      expr.second.second.first
    end

    def if_alternative(expr)
      alter_expr = expr.second.second.second
      alter_expr.nil? ? Boolean.new(false) : alter_expr.first
    end

    def make_if(predicate, consequent, alternative)
      make_nested_pairs Symbol.new('if'), predicate, consequent, alternative
    end

    def begin?(expr)
      tagged_list? expr, 'begin'
    end

    def begin_actions(expr)
      expr.second
    end

    def last_expr?(seq)
      seq.second.nil?
    end

    def first_expr(seq)
      seq.first
    end

    def rest_exprs(seq)
      seq.second
    end

    def application?(expr)
      expr.is_a?(Pair)
    end

    def application_operator(expr)
      expr.first
    end

    def application_operands(expr)
      expr.second
    end

    def has_no_operands?(ops)
      ops.nil?
    end

    def first_operand(ops)
      ops.first
    end

    def rest_operands(ops)
      ops.second
    end

    def sequence_to_expr(seq)
      if seq.nil?
        nil
      elsif last_expr?(seq)
        first_expr(seq)
      else
        Pair.new Symbol.new('begin'), seq
      end
    end

    def cond?(expr)
      tagged_list? expr, 'cond'
    end

    def cond_clauses(expr)
      expr.second
    end

    def cond_predicate(clause)
      clause.first
    end

    def cond_actions(clause)
      clause.second
    end

    def cond_else_clause?(clause)
      cond_predicate(clause) == Symbol.new('else')
    end

    def convert_cond_to_ifs(expr)
      expand_cond_clauses(cond_clauses(expr))
    end

    def expand_cond_clauses(clauses)
      return Boolean.new(false) if clauses.nil?

      first = clauses.first
      rest = clauses.second
      if cond_else_clause?(first)
        if rest.nil?
          return sequence_to_expr(cond_actions(first))
        else
          raise ExprError.new("ELSE clause is not last: #{expr_to_s(clauses)}")
        end
      else
        predicate = cond_predicate(first)
        consequent = sequence_to_expr(cond_actions(first))
        alternative = expand_cond_clauses(rest)
        return make_if(predicate, consequent, alternative)
      end
    end

    #
    # 'let' is a derived expression:
    #
    # (let ((var1 exp1) ... (varN expN))
    #     body)
    #
    # is expanded to:
    #
    # ((lambda (var1 ... varN)
    #     body)
    #   exp1
    #   ...
    #   expN)
    #
    def let?(expr)
      tagged_list?(expr, 'let')
    end

    def let_bindings(expr)
      expr.second.first
    end

    def let_body(expr)
      expr.second.second
    end

    def convert_let_to_application(expr)
      vars = []
      vals = []

      bindings = let_bindings(expr)
      while !bindings.nil?
        vars << bindings.first.first
        vals << bindings.first.second.first
        bindings = bindings.second
      end

      lambda_expr = make_lambda(make_nested_pairs(*vars), let_body(expr))
      make_nested_pairs(lambda_expr, *vals)
    end
  end
end

