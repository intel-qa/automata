module Panini::Automaton
  abstract class Finite
    SINK_STATE = "sink_state"

    @[AlwaysInline]
    private def assert_valid_start_state(start_state)
      raise ArgumentError.new("Invalid start state") unless valid? start_state
    end

    @[AlwaysInline]
    private def assert_valid_transitions
      raise ArgumentError.new("Invalid transition(s)") unless @transitions.all? do |antecedent, input_consequent_mapping|
        @states.includes?(antecedent) && input_consequent_mapping.all? do |input, consequent|
          (@symbols.includes?(input) || @epsilon && input == EPSILON) && valid? consequent
        end
      end
    end

    @[AlwaysInline]
    private def assert_valid_symbol(symbol)
      raise ArgumentError.new("Unknown symbol: #{symbol}") unless (@symbols.includes?(symbol) || @epsilon && symbol == EPSILON)
    end

    @[AlwaysInline]
    private def assert_valid_accepting_states(accepting_states)
      raise ArgumentError.new("Invalid accepting state(s)") unless @states.superset_of? accepting_states
    end

    @[AlwaysInline]
    private def assert_no_missing_transitions
      raise ArgumentError.new("No transitions provided!") if @transitions.empty?

      raise ArgumentError.new("Missing transition(s)") unless @states.all? do |state|
        next true if state == SINK_STATE

        @transitions.has_key?(state) && @symbols.all? do |sym|
          @transitions[state].has_key?(sym) || @epsilon && @transitions[state].has_key?("")
        end
      end
    end

    # transitions may be glued together, here we separate them
    private def preprocess(transitions, consequent_type : T.class = typeof(transitions.first[1].first[1])) forall T
      return transitions if transitions.is_a? Hash(State, Hash(Token, T))

      transitions.map do |antecedent, inputs_consequent_mapping|
        input_consequent_mapping = inputs_consequent_mapping.reduce({} of Token => T) do |acc, (inputs, consequent)|
          acc.merge!(inputs.is_a?(Array) ? inputs.map {|sym| {sym, consequent} }.to_h : {inputs => consequent})
        end

        {antecedent, input_consequent_mapping}
      end.to_h
    end

    @[AlwaysInline]
    private def epsilon_transitions_present?
      @transitions.any? do |antecedent, input_consequent_mapping|
        input_consequent_mapping.any? do |input, consequent|
          next true if input == EPSILON
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

  class Deterministic < Finite
    getter current : State

    @states : Set(State)
    @symbols : Set(Token)
    @transitions : Hash(State, Hash(Token, State))
    @start : State
    @accepts : Set(State)
    @epsilon : Bool

    @[AlwaysInline]
    private def valid?(state : State)
      @states.includes? state
    end

    # TODO: can use StringPool for Token tokens ?
    def initialize(@states, @symbols, transitions, start_state, accepting_states)
      assert_valid_start_state(start_state)
      assert_valid_accepting_states(accepting_states)

      @transitions = preprocess(transitions)

      raise ArgumentError.new("DFA can't have epsilon transitions!") if epsilon_transitions_present?
      @epsilon = false

      assert_valid_transitions
      assert_no_missing_transitions

      @current = @start = start_state
      @accepts = accepting_states
    end

    # delta
    private def delta(state, input_symbol : Token)
      return state if input_symbol == EPSILON

      assert_valid_symbol(input_symbol)
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

  class NonDeterministic < Finite
    getter current : Set(State)

    @states : Set(State)
    @symbols : Set(Token)
    @transitions : Hash(State, Hash(Token, Set(State)))
    @start : Set(State)
    @accepts : Set(State)
    @epsilon : Bool

    @[AlwaysInline]
    private def valid?(state_set : Set(State))
      @states.superset_of? state_set
    end

    # TODO: can use StringPool for Token tokens ?
    def initialize(@states, @symbols, transitions, start_state, accepting_states)
      assert_valid_start_state(start_state)
      assert_valid_accepting_states(accepting_states)

      @transitions = preprocess(transitions)
      @epsilon = epsilon_transitions_present?

      assert_valid_transitions
      # assert_no_missing_transitions


      @current = @start = start_state
      @accepts = accepting_states
    end

    def epsilon_closure(state : State)
      closure = Set{state}
      return closure unless @epsilon

      queue = [state]
      loop do
        current = queue.shift

        next_states = delta(current)
        queue.concat(next_states - closure)
        closure.concat(next_states)

        break if queue.empty?
      end

      closure
    end

    def epsilon_closure(state_set : Set(State))
      return state_set unless @epsilon

      state_set.reduce Set(State).new do |closure_union, state|
        closure_union | epsilon_closure(state)
      end
    end

    # delta
    private def delta(state, input_symbol = EPSILON)
      return Set{state} if !@epsilon && input_symbol == EPSILON

      assert_valid_symbol(input_symbol)

      if @transitions[state]?.nil? || @transitions[state][input_symbol]?.nil?
        Set(State).new
      else
        @transitions[state][input_symbol]
      end
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
      @current = epsilon_closure(@current).reduce Set(State).new do |consequents_union, antecedent|
        consequents_union | epsilon_closure(delta antecedent, input_symbol)
      end
      self
    end

    def process(input_symbols : Array(Token))
      @current = epsilon_closure(@current).reduce Set(State).new do |consequents_union, antecedent|
        consequents_union | epsilon_closure(delta antecedent, input_symbols)
      end
      self
    end

    private def current_accepts?
      (@accepts & @current).size > 0
    end

    def to_dfa
      dfa_transitions = {} of State => Hash(Token, State)

      start_id = Panini::Helper.state_set_to_identifier(@start)
      dfa_start = start_id
      dfa_states = Set{start_id}
      dfa_accepts = (@start & @accepts).size > 0 ? Set{start_id} : Set(State).new

      queue = [@start]

      loop do
        current = queue.shift
        current_id = Panini::Helper.state_set_to_identifier(current)
        symbol_consequent_mapping = {} of Token => State

        @symbols.each do |sym|
          consequent = epsilon_closure(current).reduce Set(State).new do |consequents_union, antecedent|
            consequents_union | epsilon_closure(delta antecedent, sym)
          end

          consequent_id = Panini::Helper.state_set_to_identifier(consequent)
          queue << consequent unless consequent_id == SINK_STATE || dfa_states.includes?(consequent_id)

          dfa_states << consequent_id
          dfa_accepts << consequent_id if (consequent & @accepts).size > 0

          symbol_consequent_mapping[sym] = consequent_id
        end

        dfa_transitions[current_id] = symbol_consequent_mapping
        break if queue.empty?
      end

      if dfa_states.includes? SINK_STATE
        dfa_transitions[SINK_STATE] = Hash(Token, State).new do |h, k|
          h[k] = SINK_STATE
        end
      end

      Deterministic.new(dfa_states, @symbols, dfa_transitions, dfa_start, dfa_accepts)
    end
  end

end
