module Panini
  struct Alphabet
    EPSILON = ""
    # an empty alphabet used as a dummy placeholder,
    # esp. for PHI and EPSILON languages
    # also used to denote that alphabet set need
    # not be used for validating strings for a given language
    NIL = Alphabet.new
    getter powers = {0 => Set{EPSILON}}
    getter symbols : Set(Char)

    # this is a memoization cache
    @vocabulary = Set(String).new

    def self.from(*chars : Char)
      self.new(chars.to_set)
    end

    def |(other)
      {{@type}}.new(self.symbols | other.symbols)
    end

    def initialize(@symbols = Set(Char).new)
    end

    private def calculate_power(exponent)
      return (@symbols.map &.to_s).to_set if exponent == 1

      Set(String).new.tap do |power|
        (self ** (exponent-1)).each do |str_x|
          (self ** 1).each do |str_a|
            power << "#{str_x}#{str_a}"
          end
        end
      end
    end

    def **(exponent)
      @powers[exponent] ||= calculate_power(exponent)
    end

    def defines?(string)
      return true if @vocabulary.includes? string

      string.chars.all?{|c| @symbols.includes? c }.tap do |defined|
        @vocabulary << string if defined
      end
    end
  end

  alias Lang = Language

  struct Language
    private INFINITY = Int32::MAX
    private UNDEFINED = Int32::MIN
    private NO_MEMBERSHIP = Set(String).new
    private REJECT_ALL = ->(s : String) {false}
    private ACCEPT_ALL = ->(s : String) {true}

    PHI = Lang.new
    EPSILON = Lang.from Alphabet::EPSILON

    getter membership : Set(String)

    getter criterion = ->(s : String) : Bool {false}
    getter alphabet : Alphabet
    getter min_size : Int32
    getter max_size : Int32

    # this is a memoization cache
    @vocabulary = Set(String).new
    getter name

    def self.from(*strings : String, name = Random::Secure.hex)
      new(membership: strings.to_set, name: name)
    end

    def self.from(*symbols : Char, name = Random::Secure.hex)
      new(alphabet: (Alphabet.from *symbols), criterion: ACCEPT_ALL, name: name)
    end

    def self.from(criterion : String -> Bool, name = Random::Secure.hex)
      new(criterion: criterion, name: name)
    end

    def self.new(
      *,
      symbols : Tuple,
      **named_args
    )
      new(
        **named_args,
        alphabet: (Alphabet.from *symbols)
      )
    end

    def initialize(
      *,
      @membership = NO_MEMBERSHIP,
      @criterion = REJECT_ALL,
      @alphabet = Alphabet::NIL,
      @min_size = 0,
      @max_size = INFINITY,
      @name = Random::Secure.hex
    )
    end

    @[AlwaysInline]
    def epsilon?
      includes? ""
    end

    # only membership is inclusion type, rest all are in reality exclusion types
    # if membership test passes, language contains the string
    # if other tests fail, language does not contain the string
    # if all other tests pass, only then language contains the string
    def includes?(string : String)
      return true if @vocabulary.includes? string

      return true if @membership == NO_MEMBERSHIP ? false : @membership.includes? string

      return false unless @min_size == UNDEFINED ? true : string.size >= @min_size
      return false unless @max_size == UNDEFINED ? true : string.size <= @max_size
      return false unless @alphabet == Alphabet::NIL ? true : @alphabet.defines? string
      return false unless @criterion.call string

      @vocabulary << POOL.get string
      true
    end

    # union
    def |(other : self)
      union_criterion = ->(string : String) do
        (self.includes? string) || other.includes? string
      end
      Language.from criterion: union_criterion, name: "#{@name}|#{other.name}"
    end

    # concatenation
    def +(other : self, epsilon_allowed = true)
      concat_criterion = ->(string : String) do
        if epsilon_allowed
          return true if self.epsilon? && other.includes? string
          return true if other.epsilon? && self.includes? string
        end

        (1...string.size).any? do |i|
          (self.includes? string[0...i]) && other.includes? string[i..-1]
        end
      end
      Language.from criterion: concat_criterion, name: "#{@name}+#{other.name}"
    end

    def **(n, epsilon_allowed = true)
      raise ArgumentError.new("Begative powers are undefined.") if n < 0
      return Lang::EPSILON if n == 0

      (1...n).reduce(self, &.+(self, epsilon_allowed))
    end

    # closure
    def ~
      closure_criterion = ->(string : String) do
        (0..string.size).any? do |i|
          # epsilon_allowed is given as false to improve performance by preventing duplicate work
          # when checking inclusion in a closure we check inclusion in the series L**0, L**1, L**2 and so on
          # for all L's.
          # epsilon_allowed as true would do this series check for each L**i, thus doing duplicate work.
          self.**(i, epsilon_allowed: false).includes? string
        end
      end

      Language.from criterion: closure_criterion, name: "~#{@name}"
    end
  end
end
