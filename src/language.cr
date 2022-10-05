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
    INFINITY = Int32::MAX
    UNDEFINED = Int32::MIN

    PHI = Lang.new
    EPSILON = Lang.from Alphabet::EPSILON

    private REJECT_ALL = ->(string : String) {false}
    private NO_MEMBERS = Set(String).new

    getter members : Set(String)
    getter min_string_size : Int32
    getter max_string_size : Int32
    @alphabet : Alphabet
    @criterion : String -> Bool

    def self.from(*strings : String)
      symbols = strings.reduce(Set(Char).new) do |acc, string|
        acc.concat string.chars
      end

      new(strings.to_set, Alphabet.new(symbols))
    end

    def self.new
      new(REJECT_ALL, Alphabet::NIL, UNDEFINED, UNDEFINED)
    end

    def self.new(membership, *args : Int32)
      new(membership, Alphabet::NIL, *args)
    end

    def self.new(membership, alphabet : Tuple, *args : Int32)
      new(membership, (Alphabet.from *alphabet), *args)
    end

    def self.new(criterion : String -> Bool, alphabet : Tuple, **named_args)
      new(criterion, (Alphabet.from *alphabet), **named_args)
    end

    def initialize(@members : Set(String), @alphabet)
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

      @criterion = REJECT_ALL
    end

    def initialize(@criterion : String -> Bool, @alphabet = Alphabet::NIL, @min_string_size = 0, @max_string_size = INFINITY)
      @members = NO_MEMBERS
    end

    @[AlwaysInline]
    private def in_range(string_len)
      return false if @min_string_size == UNDEFINED || @max_string_size == UNDEFINED
      @min_string_size <= string_len <= @max_string_size
    end

    def includes?(string : String)
      return false unless (in_range string.size)

      unless @alphabet == Alphabet::NIL
        return false unless @alphabet.defines? string
      end

      (@members.includes? string) || @criterion.call(string)
    end

    # union
    def |(other : Language)
      Language.new(
        ->(s : String) {(self.includes? s) || (other.includes? s)},
        Alphabet::NIL,
        {@min_string_size, other.min_string_size}.min,
        {@max_string_size, other.max_string_size}.max
      )
    end

    # concatenation
    def +(other : Language)
      concatanation_min = self.min_string_size + other.min_string_size
      concatanation_max = self.max_string_size == INFINITY || other.max_string_size == INFINITY ?
                            INFINITY :
                            self.max_string_size + other.max_string_size

      criterion = ->(s : String) do
        concatenation_boundary_range = self.min_string_size..s.size-other.min_string_size
        concatenation_boundary_range.any? do |i|
          (self.includes? s[0...i]) && (other.includes? s[i..-1])
        end
      end

      Language.new(criterion, concatanation_min, concatanation_max)
    end

    def **(n)
      (0...n-1).reduce self, &.+(self)
    end

    @[AlwaysInline]
    private def power_max_string_size(exponent)
      @max_string_size == INFINITY ? @max_string_size : @max_string_size * exponent
    end

    # for string_len = 9, min = 2 | 0, max = 5 | infi
    # min 2, max 5 (2..4)
    # min 2, max infi ((1)..4)
    # min 0, max 5 (2..(9))
    # min 0, max infi ((1)..(9))
    private def enclosing_exponent_range(string_len)
      enclosing_start = @max_string_size == INFINITY ? 1 : (string_len / @max_string_size).ceil.to_i
      enclosing_end = @min_string_size == 0 ? string_len : string_len // @min_string_size

      enclosing_start..enclosing_end
    end

    # closure
    def ~
      Language.new(->(s : String) { enclosing_exponent_range(s.size).any?{|i| (self ** i).includes? s } })
    end
  end

end
