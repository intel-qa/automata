require "string_pool"

module Panini::Automaton
  EPSILON = Char::ZERO
  SINK_STATE = "sink_state"

  abstract class Finite
    @[AlwaysInline]
    private def known?(symbol : Char)
      @symbols.includes?(symbol) || @epsilon_transitions_allowed && epsilon? symbol
    end

    @[AlwaysInline]
    private def epsilon?(input : String)
      input.empty?
    end

    private def epsilon?(input : Char)
      input == '\0'
    end

    @[AlwaysInline]
    private def assert_valid_start_state
      raise ArgumentError.new("Invalid start state") unless known? state: @start
    end

    @[AlwaysInline]
    private def assert_valid_transitions
      raise ArgumentError.new("Invalid transition(s)") unless @transitions.all? do |state, transitions_for_state|
        (@states.includes? state) && transitions_for_state.all? do |input, next_state|
          (known? symbol: input) && (known? state: next_state)
        end
      end
    end

    @[AlwaysInline]
    private def assert_valid(symbol)
      raise ArgumentError.new("Unknown symbol: #{symbol}") unless known? symbol: symbol
    end

    @[AlwaysInline]
    private def assert_valid_accepting_states
      raise ArgumentError.new("Invalid accepting state(s)") unless @states.superset_of? @acceptors
    end

    @[AlwaysInline]
    private def assert_no_missing_transitions
      raise ArgumentError.new("No transitions provided!") if @transitions.empty?

      raise ArgumentError.new("Missing transition(s)") unless @states.all? do |state|
        next true if state == SINK_STATE

        @transitions.has_key?(state) && @symbols.all? do |sym|
          @transitions[state].has_key?(sym) || @epsilon_transitions_allowed && @transitions[state].has_key?("")
        end
      end
    end

    # transitions may be glued together in a compact notation, here we separate them
    private def preprocess(transitions, next_state_type : T.class = typeof(transitions.first[1].first[1])) forall T
      Hash(State, Hash(Char, T)).new{ Hash(Char, T).new{T.new} }.merge! transitions.map {|state, inputs_next_state_mapping|
        transitions_for_state = inputs_next_state_mapping.reduce Hash(Char, T).new{T.new} do |acc, (inputs, next_state)|
          next_state = Helper.inventorize next_state

          mapping = inputs.is_a?(Array) ?
            inputs.map {|sym| {sym, next_state} }.to_h :
            {inputs => next_state}

          acc.merge! mapping
        end

        {(Helper.inventorize state), transitions_for_state}
      }.to_h
    end

    @[AlwaysInline]
    private def epsilon_transitions_present?
      @transitions.any? do |state, transitions_for_state|
        transitions_for_state.any? do |input, next_state|
          next true if epsilon? input
        end
      end
    end

    private abstract def delta(state, input_symbol : Char)
    private abstract def delta(state, input_symbols : String)
    private abstract def current_accepts?

    def process(input)
      @current = delta(@current, input)
      self
    end

    def accepts?(input_symbols)
      process input_symbols
      current_accepts?
    rescue e : ArgumentError
      # if wrong arguments are passed don't throw but return false
      # this ensures that Language and Automaton have the same behavior
      false
    ensure
      reset
    end

    def reset
      @current = @start
      self
    end

    def to_s(io)
      io << "<" << @states << " | " << @symbols << " | " << @transitions << " | " << @start << " | " << @acceptors << ">"
    end
  end

  class Deterministic < Finite
    getter current : State

    @states : Set(State)
    @symbols : Set(Char)
    @transitions : Hash(State, Hash(Char, State))
    @start : State
    @acceptors : Set(State)
    @epsilon_transitions_allowed = false

    @[AlwaysInline]
    private def known?(state)
      @states.includes? state
    end

    def initialize(states, @symbols, transitions, start_state, accepting_states)
      @states = Helper.inventorize states
      @start = Helper.inventorize start_state
      assert_valid_start_state

      @acceptors = Helper.inventorize accepting_states
      assert_valid_accepting_states

      @transitions = preprocess transitions
      raise ArgumentError.new("DFA can't have epsilon transitions!") if epsilon_transitions_present?

      assert_valid_transitions
      assert_no_missing_transitions

      @current = @start
    end

    # delta
    private def delta(state, input_symbol : Char)
      assert_valid(symbol: input_symbol)

      return SINK_STATE if state == SINK_STATE
      @transitions[state][input_symbol]
    end

    # delta cap
    private def delta(state, input_symbols : String)
      return state if epsilon? input_symbols

      delta(delta(state, input_symbols[0..-2]), input_symbols[-1])
    end

    private def current_accepts?
      @acceptors.includes? @current
    end

    def to_nfa
      nfa_transitions = @transitions.reduce({} of State => Hash(Char, Set(State))) do |acc, (state, transitions_for_state)|
        acc.merge! ({
          state => transitions_for_state.reduce({} of Char => Set(State)) {|acc, (token, next_state)| acc.merge!({token => Set{next_state}}) }
        })
      end

      NonDeterministic.new(@states, @symbols, nfa_transitions, Set{@start}, @acceptors)
    end
  end

  class NonDeterministic < Finite
    getter current : Set(State)

    getter states : Set(State)
    getter symbols : Set(Char)
    getter transitions : Hash(State, Hash(Char, Set(State)))
    getter start : Set(State)
    getter acceptors : Set(State)
    @epsilon_transitions_allowed : Bool

    @[AlwaysInline]
    private def known?(state)
      @states.superset_of? state
    end

    def initialize(states, @symbols, transitions, start_state, accepting_states)
      @states = Helper.inventorize states
      @start = Helper.inventorize start_state
      assert_valid_start_state

      @acceptors = Helper.inventorize accepting_states
      assert_valid_accepting_states

      @transitions = preprocess transitions
      @epsilon_transitions_allowed = epsilon_transitions_present?
      assert_valid_transitions

      @current = @start
    end

    def epsilon_closure(state : State)
      closure = Set{state}
      return closure unless @epsilon_transitions_allowed

      queue = [state]
      loop do
        current = queue.shift

        next_states = @transitions[current][EPSILON]
        queue.concat(next_states - closure)
        closure.concat(next_states)

        break if queue.empty?
      end

      closure
    end

    def epsilon_closure(state_set : Set(State))
      return state_set unless @epsilon_transitions_allowed

      state_set.reduce(Set(State).new) do |closure_union, state|
        closure_union | epsilon_closure(state)
      end
    end

    # delta
    private def delta(state, input_symbol = EPSILON)
      assert_valid(symbol: input_symbol)

      epsilon_closure(state).reduce(Set(State).new) do |next_states_union, state|
        next_states = @transitions[state][input_symbol]
        next_states_union | epsilon_closure(next_states)
      end
    end

    # delta cap
    private def delta(state, input_symbols : String)
      return epsilon_closure(state) if epsilon? input_symbols

      epsilon_closure(state).reduce Set(State).new do |next_states_union, state|
        next_states = delta(state, input_symbols[0..-2]).reduce(Set(State).new) do |states_union, next_state|
          states_union | delta(next_state, input_symbols[-1])
        end

        next_states_union | epsilon_closure(next_states)
      end
    end

    private def current_accepts?
      (@acceptors & @current).size > 0
    end

    def to_dfa
      dfa_transitions = {} of State => Hash(Char, State)

      start_closure = epsilon_closure(@start)
      start_id = Helper.state_set_to_identifier(start_closure)
      dfa_start = start_id
      dfa_states = Set{start_id}
      dfa_accepts = (start_closure & @acceptors).size > 0 ? Set{start_id} : Set(State).new

      queue = [start_closure]

      loop do
        current = queue.shift
        current_id = Helper.state_set_to_identifier(current)
        transitions_for_current = {} of Char => State

        @symbols.each do |sym|
          next_state = current.reduce Set(State).new do |next_states_union, state|
            next_states_union | epsilon_closure(delta state, sym)
          end

          next_state_id = Helper.state_set_to_identifier(next_state)
          queue << next_state unless next_state_id == SINK_STATE || dfa_states.includes? next_state_id

          dfa_states << next_state_id
          dfa_accepts << next_state_id if (next_state & @acceptors).size > 0

          transitions_for_current[sym] = next_state_id
        end

        dfa_transitions[current_id] = transitions_for_current
        break if queue.empty?
      end

      Deterministic.new(dfa_states, @symbols, dfa_transitions, dfa_start, dfa_accepts)
    end
  end

end
