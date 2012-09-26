module Rob
  class ParseError < Error; end

  class Parser
    def initialize
      @lexer = Lexer.new
      clear
    end

    def clear
      @text = ''
      @cur_token = nil
    end

    def parse(text)
      @text = text
      @lexer.input(text)
      next_token
      parse_file
    end

    def pos2coord(pos)
      subtext = @text[0..pos]
      num_newlines = subtext.count("\n")
      line_offset = subtext.rindex("\n")

      line_offset = 0 if line_offset.nil? || line_offset < 0

      "[line #{num_newlines+1}, column #{pos - line_offset}]"
    end

  private
    def parse_error(msg, token=@cur_token)
      if token
        coord = pos2coord(token.pos)
        raise ParseError.new("#{msg} #{coord}")
      else
        raise ParseError.new(msg)
      end
    end

    def next_token
      loop do
        @cur_token = @lexer.token
        break if @cur_token.nil? || @cur_token.type != :comment
      end
    rescue LexerError => e
      raise ParseError.new("syntax error at #{pos2coord(e.pos)}")
    end

    def match(type)
      if @cur_token.type == type
        val = @cur_token.val
        next_token
        return val
      else
        parse_error "Unmatched #{type} (found #{@cur_token.type})"
      end
    end

    def parse_file
      [].tap do |list|
        while @cur_token
          list << parse_datum
        end
      end
    end

    def parse_datum
      if @cur_token.type == :lparen
        parse_list
      elsif @cur_token.type == :quote
        parse_abbreviation
      else
        parse_atom
      end
    end

    def parse_atom
      case @cur_token.type
      when :boolean
        ret = Boolean.new(@cur_token.val == '#t')
      when :number
        base = 10
        num_str = @cur_token.val
        if num_str[0] == '#'
          case num_str[1]
          when 'x'; base = 16
          when 'o'; base = 8
          when 'b'; base = 2
          end
          num_str = num_str[2..-1]
        end
        begin
          ret = Number.new(Integer(num_str, base))
        rescue ArgumentError
          parse_error "Invalid number"
        end
      when :id
        ret = Symbol.new(@cur_token.val)
      else
        parse_error "Unexpected token #{@cur_token.val}"
      end

      next_token
      ret
    end

    # First parse all atoms into a Ruby array, then convert
    # to nested Pairs. For dotted pairs, +dot_idx+ keeps
    # track of the index in the list where the dot was found.
    def parse_list
      match :lparen
      list = []
      dot_idx = -1

      loop do
        if !@cur_token
          parse_error "Unmatched parentheses at end of input"
        elsif @cur_token.type == :rparen
          break
        elsif @cur_token.type == :id and @cur_token.val == '.'
          parse_error "Invalid '.' usage" if dot_idx > 0
          dot_idx = list.length
          match :id
        else
          list << parse_datum
        end
      end

      dotted_end = false
      if dot_idx > 0
        if dot_idx == list.length - 1
          dotted_end = true
        else
          parse_error "Invalid location for '.' in list"
        end
      end

      match :rparen

      if dotted_end
        cur_cdr = list[-1]
        list = list[0...-1]
      else
        cur_cdr = nil
      end

      list.reverse.each do |atom|
        cur_cdr = Pair.new(atom, cur_cdr)
      end

      cur_cdr
    end

    def parse_abbreviation
      quote_pos = @cur_token.pos
      match :quote
      datum = parse_datum
      Pair.new(Symbol.new('quote'), Pair.new(datum, nil))
    end
  end
end
