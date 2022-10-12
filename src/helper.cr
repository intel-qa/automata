module Panini::Helper
  extend self

  POOL = StringPool.new

  @[AlwaysInline]
  def inventorize(string : String)
    POOL.get string
  end

  @[AlwaysInline]
  def inventorize(strings : Set(String))
    strings.map{|s| POOL.get s }.to_set
  end

  @[AlwaysInline]
  def state_set_to_identifier(states)
    states.empty? ? Automaton::SINK_STATE : states.to_a.sort.join("")
  end

  @[AlwaysInline]
  def random_name(size = 8)
    Random::Secure.hex(size//2)
  end

  # construct composite nfa from basis nfas.
  # basis nfa is nfa for basis regular languages
  # basis regular languages are Lang::PHI, Lang::EPSILON, Lang.from single_symbol
  def nfa_datum(regularity, nfa_data : Array(Language::NFADatum))
    start = random_name
    final = random_name

    transitions = nfa_data.reduce({} of State => Hash(Char, Set(State))) do |acc, nfa_datum|
      acc.merge! nfa_datum[:transitions]
    end

    case regularity
    when Language::Regularity::Union
      transitions.merge! ({
        start => {Automaton::EPSILON => Set{nfa_data[0][:start], nfa_data[1][:start]}},

        nfa_data[0][:final] => {Automaton::EPSILON => Set{final}},
        nfa_data[1][:final] => {Automaton::EPSILON => Set{final}},
      })
    when Language::Regularity::Concat
      transitions.merge! ({
        start               => {Automaton::EPSILON => Set{nfa_data[0][:start]}},
        nfa_data[0][:final] => {Automaton::EPSILON => Set{nfa_data[1][:start]}},
        nfa_data[1][:final] => {Automaton::EPSILON => Set{final}              },
      })
    when Language::Regularity::Closure
      transitions.merge! ({
        start               => {Automaton::EPSILON => Set{final, nfa_data[0][:start]}},
        nfa_data[0][:final] => {Automaton::EPSILON => Set{final, nfa_data[0][:start]}},
      })
    else
      raise ArgumentError.new("Invalid regularity provided.")
    end

    {
      states: nfa_data.reduce(Set(State).new) {|acc, nfa_datum| acc | nfa_datum[:states] } << start << final,
      symbols: nfa_data.reduce(Set(Char).new) {|acc, nfa_datum| acc | nfa_datum[:symbols] },
      transitions: transitions,
      start: start,
      final: final
    }
  end
end
