module Rob
  class Env
    class UnboundError < Error; end

    attr_reader :binding, :parent

    def initialize(binding, parent=nil)
      @binding = binding
      @parent = parent
    end

    def lookup_var(var)
      if bound?(var)
        binding[var]
      elsif !parent.nil?
        parent.lookup_var(var)
      else
        unbound!(var)
      end
    end

    def define_var(var, value)
      binding[var] = value
    end

    def set_var_value(var, value)
      if bound?(var)
        binding[var] = value
      elsif !parent.nil?
        parent.set_var_value(var, value)
      else
        unbound!(var)
      end
    end

    def bound?(var)
      binding.has_key?(var)
    end

    def unbound!(var)
      raise UnboundError.new("unbound variable '#{var}'")
    end
  end
end
