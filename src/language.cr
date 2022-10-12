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

    def initialize(@symbols = Set(Char).new)
    end

    def |(other)
      {{@type}}.new(self.symbols | other.symbols)
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
        @vocabulary << Helper.inventorize string if defined
      end
    end
  end

  alias Lang = Language

  class Language
    alias NFADatum = NamedTuple(states: Set(String), symbols: Set(Char), transitions: Hash(String, Hash(Char, Set(String))), start: String, final: String)

    class AlphabetNotFoundError < Exception
    end

    class IrregularFiniteAutomatonError < Exception
    end

    enum Regularity
      Phi
      Epsilon
      Symbol
      Union
      Concat
      Closure
      None
    end

    private INFINITY = Int32::MAX
    private UNDEFINED = Int32::MIN
    private NO_MEMBERSHIP = Set(String).new
    private REJECT_ALL = ->(s : String) {false}
    private ACCEPT_ALL = ->(s : String) {true}

    PHI = Lang.new
    EPSILON = Lang.from Alphabet::EPSILON

    getter membership = NO_MEMBERSHIP

    # TODO replace with REJECT_ALL?
    getter criterion = ->(s : String) : Bool {false}
    getter alphabet = Alphabet::NIL
    getter min_size = 0
    getter max_size = INFINITY
    @constituents = [] of Language

    # this is a memoization cache
    @vocabulary = Set(String).new
    getter name

    private getter regularity = Regularity::None

    @nfa_datum : NFADatum?

    def self.from(*strings : String)
      new(membership: strings.to_set, name: Helper.random_name)
    end

    def self.from(*symbols : Char)
      new(alphabet: (Alphabet.from *symbols), criterion: ACCEPT_ALL, name: Helper.random_name)
    end

    def self.from(criterion : String -> Bool)
      new(criterion: criterion, name: Helper.random_name)
    end

    def self.new(
      *,
      alphabets : Tuple,
      **named_args
    )
      new(
        **named_args,
        alphabet: (Alphabet.from *alphabets)
      )
    end

    def initialize(
      *,
      membership = NO_MEMBERSHIP,
      @criterion = REJECT_ALL,
      @alphabet = Alphabet::NIL,
      @min_size = 0,
      @max_size = INFINITY,
      @name = Helper.random_name
    )
      @membership = Helper.inventorize membership

      if @criterion == REJECT_ALL && @alphabet == Alphabet::NIL && @min_size == 0 && @max_size == INFINITY
        if @membership.size == 1 && @membership.first.size == 1
          @regularity = Regularity::Symbol
        elsif @membership == Set{""}
          @regularity = Regularity::Epsilon
        elsif @membership == NO_MEMBERSHIP
          @regularity = Regularity::Phi
        end
      end
    end

    def initialize(operation : Regularity, *constituents : Language, ignore_epsilon = false)
      constituents = constituents.to_a

      case operation
      when Regularity::Union
        raise ArgumentError.new("Expected 2 constituents for Union") unless constituents.size == 2

        @name = constituents.map(&.name).join('|')
        @criterion = ->(string : String) do
          constituents.any? do |l|
            l.includes? string
          end
        end
      when Regularity::Concat
        raise ArgumentError.new("Expected 2 constituents for Concatenation") unless constituents.size == 2
        lang1 = constituents[0]
        lang2 = constituents[1]

        @name = "#{lang1}+#{lang2}"
        @criterion = ->(string : String) do
          unless ignore_epsilon
            return true if lang1.includes_epsilon? && lang2.includes? string
            return true if lang2.includes_epsilon? && lang1.includes? string
          end

          (1...string.size).any? do |i|
            (lang1.includes? string[0...i]) && lang2.includes? string[i..-1]
          end
        end
      when Regularity::Closure
        raise ArgumentError.new("Expected 1 constituent for Closure") unless constituents.size == 1
        lang = constituents[0]

        @name = "~#{lang.name}"
        @criterion = ->(string : String) do
          (0..string.size).any? do |i|
            # ignore_epsilon is given as true to improve performance by preventing duplicate work
            # when checking inclusion in a closure we check inclusion in the series L**0, L**1, L**2 and so on
            # for all L's.
            # ignore_epsilon as false would do this series check for each L**i instead once for teh closure,
            # thus doing duplicate work.
            lang.**(i, ignore_epsilon: true).includes? string
          end
        end
      else
        raise ArgumentError.new("Invalid operation provided.")
      end

      # regularity is operation because the definition of
      # regular languages is based on operations: union, concatanation, closure
      @regularity = operation
      @constituents = constituents
    end

    @[AlwaysInline]
    def includes_epsilon?
      self.includes? ""
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

      return false unless @criterion.call(string)

      # cache for member strings for performance
      @vocabulary << Helper.inventorize string
      true
    end

    def words(size)
      if @alphabet == Alphabet::NIL
        raise AlphabetNotFoundError.new("Can't words words as the language does not have alphabets.")
      end

      return @membership.select{|word| word.size == size }.to_set unless @membership == NO_MEMBERSHIP

      (@alphabet ** size).select{|word| self.includes? word }.to_set
    end

    # union
    def |(other : self)
      Lang.new(Regularity::Union, self, other)
    end

    # concatenation
    def +(other : self, ignore_epsilon = false)
      Language.new(Regularity::Concat, self, other, ignore_epsilon: ignore_epsilon)
    end

    def **(n, ignore_epsilon = false)
      raise ArgumentError.new("Negative powers are undefined.") if n < 0
      return Lang::EPSILON if n == 0

      (1...n).reduce(self, &.+(self, ignore_epsilon))
    end

    # closure
    def ~
      Language.new(Regularity::Closure, self, ignore_epsilon: true)
    end

    def regular?
      case regularity
      when Regularity::None                                           then false
      when Regularity::Phi, Regularity::Epsilon, Regularity::Symbol   then true
      when Regularity::Union, Regularity::Concat, Regularity::Closure then @constituents.all? &.regular?
      else
        raise ArgumentError.new("Invalid regularity.")
      end
    end

    private def basis_nfa_datum
      start = Panini::Helper.random_name
      final = Panini::Helper.random_name
      symbols = Set(Char).new

      case regularity
      when Regularity::Phi
        transitions = {} of State => Hash(Char, Set(State))
      when Regularity::Epsilon
        transitions = {start => {Automaton::EPSILON => Set{final}}}
      when Regularity::Symbol
        symbol = @membership.first.chars.first
        symbols << symbol
        transitions = {start => {symbol => Set{final}}}
      else
        raise ArgumentError.new("Trying to convert non-basis language to basis NFA.")
      end

      {
        states: Set{start, final},
        symbols: symbols,
        transitions: transitions,
        start: start,
        final: final
      }
    end

    private def calculate_nfa_datum
      case regularity
      when Regularity::Phi, Regularity::Epsilon, Regularity::Symbol
        basis_nfa_datum
      when Regularity::Union, Regularity::Concat, Regularity::Closure
        Helper.nfa_datum(regularity, @constituents.map &.nfa_datum.as(NFADatum))
      else
        # TODO: DRY
        raise ArgumentError.new("Invalid regularity.")
      end
    end

    def nfa_datum
      if regularity == Regularity::None
        raise IrregularFiniteAutomatonError.new("Trying to convert irregular language to finite automaton.")
      end

      return @nfa_datum.as(NFADatum) unless @nfa_datum.nil?
      @nfa_datum = calculate_nfa_datum
    end

    def to_nfa
      Automaton::NonDeterministic.new(
        states: nfa_datum[:states],
        symbols: nfa_datum[:symbols],
        transitions: nfa_datum[:transitions],
        start_state: Set{nfa_datum[:start]},
        accepting_states: Set{nfa_datum[:final]},
      )
    end
  end
end
