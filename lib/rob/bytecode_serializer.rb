module Rob
  class BytecodeSerializer
    MAGIC = 0x00010B0B

    TYPE_NULL       = "0"
    TYPE_BOOLEAN    = "b"
    TYPE_STRING     = "s"
    TYPE_SYMBOL     = "S"
    TYPE_NUMBER     = "n"
    TYPE_PAIR       = "p"
    TYPE_INSTR      = "i"
    TYPE_SEQUENCE   = "["
    TYPE_CODEOBJECT = "c"

    def serialize_bytecode(codeobj)
      s = word(MAGIC) + codeobject(codeobj)
    end

    # A 32-bit little-endian integer
    def word(val)
       [val].pack("V")
    end

    # A Ruby ASCII string, used for representing names in code
    # and Symbol objects.
    def string(str)
      TYPE_STRING +
        word(str.length) +
        str.encode!("ASCII")
    end

    # Serialize an arbitrary object
    def object(obj)
      case obj
      when nil;             null(obj)
      when Boolean;         boolean(obj)
      when Number;          number(obj)
      when Symbol;          symbol(obj)
      when Pair;            pair(obj)
      when VM::Instruction; instruction(obj)
      when VM::CodeObject;  codeobject(obj)
      when Array;           sequence(obj)
      when String;          string(obj)
      end
    end

    def null(*)
      TYPE_NULL
    end

    def boolean(val)
      TYPE_BOOLEAN + val ? "\x01" : "\x00"
    end

    def number(val)
      TYPE_NUMBER + word(val.value)
    end

    def symbol(val)
      TYPE_SYMBOL +
        word(val.value.length) +
        val.value.encode!("ASCII")
    end

    def pair(val)
      TYPE_PAIR +
        object(val.first) +
        object(val.second)
    end

    def sequence(seq)
      TYPE_SEQUENCE +
        word(seq.length) +
        seq.map { |x| object(x) }.join('')
    end

    def instruction(instr)
      arg = instr.arg || 0
      instr_word = (instr.opcode << 24) | (arg & 0xFFFFFF)
      TYPE_INSTR + word(instr_word)
    end

    def codeobject(code)
      TYPE_CODEOBJECT +
        string(code.name) +
        sequence(code.args) +
        sequence(code.constants) +
        sequence(code.varnames) +
        sequence(code.code)
    end
  end
end