module Rob
 # Lexer error.
  # pos:
  #   Position in the input line where the error occurred
  class LexerError < Error
    attr_reader :pos

    def initialize(pos)
      super
      @pos = pos
    end
  end

  # A simple token structure.
  # Contains the token type, value, and position.
  class Token
    attr_reader :type, :val, :pos

    def initialize(type, val, pos)
      @type = type
      @val = val
      @pos = pos
    end

    def to_s
      "#{type}(#{val}) at #{pos}"
    end
  end

   # A simple regex based lexer/tokenizer.
  class Lexer
    # Create a lexer
    def initialize(skip_ws=true)
      @skip_ws = skip_ws
    end

    # Initialize the lexer with a buffer as input.
    def input(buf)
      @scanner = StringScanner.new(buf)
      self
    end

    # Return the next token (as a Token object) found in the
    # input buffer. nil is returned if the end of the buffer
    # was reached.
    # In case of a lexing error (the current chunk of the buffer
    # matches no rule), a LexerError is raised with the position
    # of the error.
    def token
      @scanner.skip(/\s*/) if @skip_ws

      return nil if @scanner.eos?

      bin_num = /\#b[0-1]+/
      oct_num = /\#o[0-7]+/
      dec_num = /(\#d)?[0-9]+/
      hex_num = /\#x[0-9A-Fa-f]+/

      initial = /([a-zA-Z]|[!$%&*.:<=>?^_~])/
      subsequent = /(#{initial}|[0-9]|[+-.@])/

      rules = {
        comment: /;[^\n]*/,
        boolean: /#[tf]/,
        number:  /(#{bin_num}|#{oct_num}|#{hex_num}|#{dec_num})/,
        id:      /(#{initial}#{subsequent}*|([+\-.]|\.\.\.))/,
        lparen:  /\(/,
        rparen:  /\)/,
        quote:   /'/
      }

      rules.each do |token_type, regexp|
        if (m = @scanner.scan(regexp))
          return Token.new(token_type, m, @scanner.pos)
        end
      end

      raise LexerError.new(@scanner.pos)
    end

    def tokens
      Enumerator.new do |y|
        while (tok = token)
          y.yield tok
        end
      end
    end
  end
end
