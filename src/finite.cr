module Panini::Finite
  # macro assert_valid_start_state(type)
  #   {% if type == :deterministic %}
  #     raise ArgumentError.new("Invalid start state") unless @states.includes? start_state
  #   {% elsif type == :non_deterministic %}
  #     raise ArgumentError.new("Invalid start state") unless @states.superset_of? start_state
  #   {% else %}
  #     raise ArgumentError.new("Invalid automaton type")
  #   {% end %}
  # end

  # macro assert_valid_accepting_states
  #   raise ArgumentError.new("Invalid accepting state(s)") unless @states.superset_of? accepting_states
  # end

  # macro assert_valid_transitions(type)
  #   raise ArgumentError.new("Invalid transition(s)") unless @transitions.all? do |antecedent, input_consequent_mapping|
  #     @states.includes?(antecedent) && input_consequent_mapping.all? do |input, consequents|
  #       valid_symbols = @symbols.includes?(input)
  #       {% if type == :deterministic %}
  #         valid_symbols && @states.includes?(consequents)
  #       {% elsif type == :non_deterministic %}
  #         valid_symbols && @states.superset_of?(consequents)
  #       {% else %}
  #         raise "Invalid automaton type"
  #       {% end %}
  #     end
  #   end
  # end

  # macro assert_no_missing_transitions
  #   raise ArgumentError.new("No transitions provided!") if @transitions.empty?

  #   raise ArgumentError.new("Missing transition(s)") unless states.all? do |state|
  #     @transitions.has_key?(state) && @symbols.all? do |sym|
  #       @transitions[state].has_key?(sym)
  #     end
  #   end
  # end

  # macro assert_valid_symbol
  #   raise ArgumentError.new("Unknown symbol") unless @symbols.includes? input_symbol
  # end

  abstract class Automaton
    @[AlwaysInline]
    def self.assert_valid_symbol(symbol, symbols)
      raise ArgumentError.new("Unknown symbol") unless symbols.includes? symbol
    end

    @[AlwaysInline]
    def self.assert_valid_accepting_states(accepting_states, states)
      raise ArgumentError.new("Invalid accepting state(s)") unless states.superset_of? accepting_states
    end

    @[AlwaysInline]
    def self.assert_no_missing_transitions(transitions, states, symbols)
      raise ArgumentError.new("No transitions provided!") if transitions.empty?

      raise ArgumentError.new("Missing transition(s)") unless states.all? do |state|
        transitions.has_key?(state) && symbols.all? do |sym|
          transitions[state].has_key?(sym)
        end
      end
    end

    private abstract def delta(state, input_symbol : Token)
    private abstract def delta(state, input_symbols : Array(Token))
    abstract def process(input_symbol : Token)
    abstract def process(input_symbols : Array(Token))

    def accepts?(input_symbols)
      process(input_symbols)
      current_accepts?
    end

    abstract def current_accepts?

    def reset
      @current = @start
      self
    end
  end

  class Deterministic < Automaton
    @[AlwaysInline]
    def self.assert_valid_start_state(start_state, states)
      raise ArgumentError.new("Invalid start state") unless states.includes? start_state
    end

    @[AlwaysInline]
    def self.assert_valid_transitions(transitions, states, symbols)
      raise ArgumentError.new("Invalid transition(s)") unless transitions.all? do |antecedent, input_consequent_mapping|
        states.includes?(antecedent) && input_consequent_mapping.all? do |input, consequents|
          symbols.includes?(input) && states.includes?(consequents)
        end
      end
    end

    getter current : State

    @states : Set(State)
    @symbols : Set(Token)
    @transitions : Hash(State, Hash(Token, State))
    @start : State
    @accepts : Set(State)

    # TODO: can use StringPool for Token tokens ?
    def initialize(@states, @symbols, @transitions, start_state, accepting_states)
      Deterministic.assert_valid_start_state(start_state, @states)
      Automaton.assert_valid_accepting_states(accepting_states, states)
      Deterministic.assert_valid_transitions(@transitions, @states, @symbols)
      Automaton.assert_no_missing_transitions(@transitions,  @states, @symbols)

      @current = @start = start_state
      @accepts = accepting_states
    end

    # delta
    private def delta(state, input_symbol : Token)
      return state if input_symbol.empty?

      Automaton.assert_valid_symbol(input_symbol, @symbols)
      @transitions[state][input_symbol]
    end

    # delta cap
    # TODO: check if crystal supports tail call optimization
    # move to iteration from recursion if not
    private def delta(state, input_symbols : Array(Token))
      return state if input_symbols.empty?

      consequent = delta(state, input_symbols[0])
      delta(consequent, input_symbols[1..])
    end

    def process(input_symbol : Token)
      @current = delta(@current, input_symbol)
      self
    end

    def process(input_symbols : Array(Token))
      @current = delta(@current, input_symbols)
      self
    end

    private def current_accepts?
      @accepts.includes? @current
    end

    def to_nfa
      nfa_transitions = @transitions.reduce({} of State => Hash(Token, Set(State))) do |nfa_transitions, (antecedent, input_consequent_mapping)|
        nfa_transitions[antecedent] = input_consequent_mapping.reduce({} of Token => Set(State)) do |nfa_transitions_per_state, (token, consequent)|
          nfa_transitions_per_state[token] = Set{consequent}
          nfa_transitions_per_state
        end
        nfa_transitions
      end

      NonDeterministic.new(@states, @symbols, nfa_transitions, Set{@start}, @accepts)
    end
  end

  class NonDeterministic < Automaton
    @[AlwaysInline]
    def self.assert_valid_start_state(start_state, states)
      raise ArgumentError.new("Invalid start state") unless states.superset_of? start_state
    end

    @[AlwaysInline]
    def self.assert_valid_transitions(transitions, states, symbols, epsilon = false)
      raise ArgumentError.new("Invalid transition(s)") unless transitions.all? do |antecedent, input_consequent_mapping|
        states.includes?(antecedent) && input_consequent_mapping.all? do |input, consequents|
          symbols.includes?(input) && states.superset_of?(consequents)
        end
      end
    end

    getter current : Set(State)

    @states : Set(State)
    @symbols : Set(Token)
    @transitions : Hash(State, Hash(Token, Set(State)))
    @start : Set(State)
    @accepts : Set(State)

    # TODO: can use StringPool for Token tokens ?
    def initialize(@states, @symbols, @transitions, start_state, accepting_states)
      NonDeterministic.assert_valid_start_state(start_state, @states)
      Automaton.assert_valid_accepting_states(accepting_states, @states)
      NonDeterministic.assert_valid_transitions(@transitions, @states, @symbols)
      Automaton.assert_no_missing_transitions(@transitions,  @states, @symbols)

      @current = @start = start_state
      @accepts = accepting_states
    end

    # delta
    private def delta(state, input_symbol : Token)
      return Set{state} if input_symbol.empty?

      Automaton.assert_valid_symbol(input_symbol, @symbols)
      @transitions[state][input_symbol]
    end

    # delta cap
    private def delta(state, input_symbols : Array(Token))
      return Set{state} if input_symbols.empty?

      consequents = delta(state, input_symbols[0])

      consequents.reduce Set(State).new do |states_union, consequent|
        states_union | delta(consequent, input_symbols[1..])
      end
    end

    def process(input_symbol : Token)
      @current = @current.reduce Set(State).new do |consequents_union, antecedent|
        consequents_union | delta(antecedent, input_symbol)
      end
      self
    end

    def process(input_symbols : Array(Token))
      @current = @current.reduce Set(State).new do |consequents_union, antecedent|
        consequents_union | delta(antecedent, input_symbols)
      end
      self
    end

    private def current_accepts?
      (@accepts & @current).size > 0
    end

    def to_dfa
      dfa_transitions = {} of State => Hash(Token, State)

      start_id = Panini.state_set_to_identifier(@start)
      dfa_start = start_id
      dfa_states = Set{start_id}
      dfa_accepts = (@start & @accepts).size > 0 ? Set{start_id} : Set(State).new

      queue = [@start]

      loop do
        current = queue.shift
        current_id = Panini.state_set_to_identifier(current)
        symbol_consequent_mapping = {} of Token => State

        @symbols.each do |sym|
          consequent = current.reduce Set(State).new do |consequents_union, antecedent|
            consequents_union | delta(antecedent, sym)
          end
          consequent_id = Panini.state_set_to_identifier(consequent)
          queue << consequent unless dfa_states.includes? consequent_id

          dfa_states << consequent_id
          dfa_accepts << consequent_id if (consequent & @accepts).size > 0

          symbol_consequent_mapping[sym] = consequent_id
        end

        dfa_transitions[current_id] = symbol_consequent_mapping
        break if queue.empty?
      end

      Deterministic.new(dfa_states, @symbols, dfa_transitions, dfa_start, dfa_accepts)
    end
  end

end
