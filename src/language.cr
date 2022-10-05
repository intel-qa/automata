module Panini
  struct Alphabet
    EPSILON = ""
    # an empty alphabet used as a dummy placeholder,
    # esp. for PHI and EPSILON languages
    NIL = Alphabet.new
    getter powers = {0 => Set{EPSILON}}
    getter symbols : Set(Char)

    def self.from(*chars : Char)
      self.new(chars.to_set)
    end

    def initialize(@symbols = Set(Char).new)
    end

    private def calculate_power(exponent)
      Set(String).new.tap do |power|
        (self ** (exponent-1)).each do |str_x|
          (self ** 1).each do |str_a|
            power << "#{str_x}#{str_a}"
          end
        end
      end
    end

    def **(exponent)
      return @powers[exponent] if @powers[exponent]?
      return @powers[exponent] = (@symbols.map &.to_s).to_set if exponent == 1

      @powers[exponent] = calculate_power(exponent)
    end

    def defines?(string)
      return true if string.empty?
      string.chars.all?{|c| @symbols.includes? c }
    end
  end

  alias Lang = Language

  struct Language
    alias Rule = String -> Bool

    macro rule(condition)
      Rule.new {|string| {{condition}} }
    end

    INFINITY = Int32::MAX
    UNDEFINED = Int32::MIN

    PHI = Lang.new
    EPSILON = Lang.from Alphabet::EPSILON

    getter members : Set(String)?
    getter min_string_size : Int32
    getter max_string_size : Int32
    @alphabet : Alphabet
    @rules : Tuple(Rule)

    def self.from(*strings : String)
      symbols = strings.reduce(Set(Char).new) do |acc, string|
        acc.concat string.chars
      end

      new(symbols, strings.to_set)
    end

    def self.new
      new(Alphabet::NIL, {rule(false)}, UNDEFINED, UNDEFINED)
    end

    def self.new(symbols : Set(Char), *args)
      new(Alphabet.new(symbols), *args)
    end

    def self.new(symbols : Tuple, *args)
      new((Alphabet.from *symbols), *args)
    end

    def initialize(@alphabet, @members)
      members = @members
      if members.nil?
        raise ArgumentError.new("Initialize attempted for membered lang without members")
      end

      unless members.all?{|m| @alphabet.defines? m }
        raise ArgumentError.new("Alphabet #{@alphabet} does not enclose all member strings #{members}}")
      end

      @min_string_size = INFINITY
      @max_string_size = 0

      members.each do |m|
        size = m.size
        @min_string_size = size if size < @min_string_size
        @max_string_size = size if size > @max_string_size
      end

      @rules = {rule(members.includes? string)}
    end

    def initialize(@alphabet, @rules, @min_string_size, @max_string_size = INFINITY)
    end

    @[AlwaysInline]
    private def in_range(string_len)
      return false if @min_string_size == UNDEFINED || @max_string_size == UNDEFINED
      @min_string_size <= string_len <= @max_string_size
    end

    def includes?(string : String)
      return false unless in_range string.size

      (@rules.all? &.call(string)).tap do |included|
        raise ArgumentError.new("min_string_size and max_string_size limits conflict with the block output") if included && !(in_range string.size)
      end
    end

    def size
      members = @members
      return members.size unless members.nil?

      INFINITY
    end

    # union
    def |(other : Language)
      members = @members
      other_members = other.members

      if members.nil? || other_members.nil?
        Language.new({@min_string_size, other.min_string_size}.min, {@max_string_size, other.max_string_size}.max) do |string|
          (self.includes? string) || (other.includes? string)
        end
      else
        Language.new(members | other_members)
      end
    end

    # concatenation
    def +(other : Language)
      self_members = self.members
      other_members = other.members

      if self_members.nil? || other_members.nil?
        concatanation_min = self.min_string_size + other.min_string_size
        concatanation_max = ([self.max_string_size, other.max_string_size].includes? INFINITY) ? INFINITY : self.max_string_size + other.max_string_size

        Language.new(concatanation_min, concatanation_max) do |string|
          concatenation_boundary_range = self.min_string_size..string.size-other.min_string_size
          concatenation_boundary_range.any? do |i|
            (self.includes? string[0...i]) && (other.includes? string[i..-1])
          end
        end
      else
        concatenated_members = Set(String).new
        self_members.each do |m1|
          other_members.each do |m2|
            concatenated_members << "#{m1}#{m2}"
          end
        end
        Language.new(concatenated_members)
      end
    end

    # TODO: this may take lot of memory if n is huge
    def **(n)
      (0...n-1).reduce(self) do |acc|
        acc + self
      end
    end

    private def enclosing_exponent_range(string_len)
      return @min_string_size..INFINITY if @max_string_size == INFINITY

      limits = Array(Int32).new(initial_capacity: 2)
      exponent = 0
      loop do
        # TODO: hadndle cases when @max_string_size = INFINITY
        enclosed = @min_string_size * exponent <= string_len <= @max_string_size * exponent
        limits << exponent if enclosed && limits.empty?

        return (limits[0]..) if @min_string_size == 0

        if !enclosed && limits.size == 1
          limits << exponent-1
          return limits[0]..limits[1]
        end
      end
    end

    # closure
    def ~
      Language.new do |string|
        exponent_range =  enclosing_exponent_range(string.size)
        if exponent_range.end.nil?
          exponent_range = exponent_range.begin..exponent_range.begin+10
        end

        exponent_range.any? do |i|
          (self ** i).includes? string
        end
      end
    end
  end

end
