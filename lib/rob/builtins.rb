module Rob
  class BuiltinError < Error; end

  class BuiltinProcedure
    attr_reader :name, :fn

    def initialize(name, fn)
      @name = name
      @fn = fn
    end

    def apply(args)
      @fn.call(args)
    end
  end

  Builtins = {
    'pair?' => lambda { |args|
      Boolean.new args[0].is_a?(Pair)
    },

    'boolean?' => lambda { |args|
      Boolean.new args[0].is_a?(Boolean)
    },

    'symbol?' => lambda { |args|
      Boolean.new args[0].is_a?(Symbol)
    },

    'number?' => lambda { |args|
      Boolean.new args[0].is_a?(Number)
    },

    'zero?' => lambda { |args|
      Boolean.new args[0].is_a?(Number) && args[0].value == 0
    },

    'null?' => lambda { |args|
      Boolean.new args[0].nil?
    },

    'cons' => lambda { |args|
      Pair.new args[0], args[1]
    },

    'list' => lambda { |args|
      ExprFunctions::make_nested_pairs(*args)
    },

    'car' => lambda { |args|
      args[0].first
    },

    'cdr' => lambda { |args|
      args[0].second
    },

    'cadr' => lambda { |args|
      args[0].second.first
    },

    'caddr' => lambda { |args|
      args[0].second.second.first
    },

    'set-car!' => lambda { |args|
      args[0].first = args[1]
      nil
    },

    'set-cdr!' => lambda { |args|
      args[0].second = args[1]
      nil
    },

    'eqv?' => lambda { |args|
      left, right = args[0], args[1]
      if left.is_a?(Pair) && right.is_a?(Pair)
        Boolean.new left.equal?(right)
      else
        Boolean.new(left == right)
      end
    },

    'eq?' => lambda { |args|
      left, right = args[0], args[1]
      if left.is_a?(Pair) && right.is_a?(Pair)
        Boolean.new left.equal?(right)
      else
        Boolean.new(left == right)
      end
    },

    'not' => lambda { |args|
      if args[0].is_a?(Boolean) && !args[0].value
        Boolean.new(true)
      else
        Boolean.new(false)
      end
    },

    'and' => lambda { |args|
      args.each { |v| return v if v == Boolean.new(false) }
      if args.length > 0
        args[-1]
      else
        Boolean.new(true)
      end
    },

    'or' => lambda { |args|
      args.each { |v| return v if v == Boolean.new(true) }
      if args.length > 0
        args[-1]
      else
        Boolean.new(true)
      end
    },

    '+' => lambda { |args|
      Number.new(args[1..-1].inject(args.first.value) {|a,x| a + x.value})
    },

    '-' => lambda { |args|
      Number.new(args[1..-1].inject(args.first.value) {|a,x| a - x.value})
    },

    '*' => lambda { |args|
      Number.new(args[1..-1].inject(args.first.value) {|a,x| a * x.value})
    },

    'quotient' => lambda { |args|
      Number.new(args[1..-1].inject(args.first.value) {|a,x| a / x.value})
    },

    'modulo' => lambda { |args|
      Number.new(args[1..-1].inject(args.first.value) {|a,x| a % x.value})
    },

    '=' => lambda { |args|
      a = args.first
      args[1..-1].each do |b|
        if a.value == b.value
          a = b
        else
          return Boolean.new(false)
        end
      end
      Boolean.new(true)
    },

    '>=' => lambda { |args|
      a = args.first
      args[1..-1].each do |b|
        if a.value >= b.value
          a = b
        else
          return Boolean.new(false)
        end
      end
      Boolean.new(true)
    },

    '<=' => lambda { |args|
      a = args.first
      args[1..-1].each do |b|
        if a.value <= b.value
          a = b
        else
          return Boolean.new(false)
        end
      end
      Boolean.new(true)
    },

    '>' => lambda { |args|
      a = args.first
      args[1..-1].each do |b|
        if a.value > b.value
          a = b
        else
          return Boolean.new(false)
        end
      end
      Boolean.new(true)
    },

    '<' => lambda { |args|
      a = args.first
      args[1..-1].each do |b|
        if a.value < b.value
          a = b
        else
          return Boolean.new(false)
        end
      end
      Boolean.new(true)
    },
  }
end
