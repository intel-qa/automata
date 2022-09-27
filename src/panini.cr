require "./finite"

# TODO: Write documentation for `Panini`
module Panini
  VERSION = "0.1.0"

  EPSILON = ""

  alias State = String
  alias Token = String

  module Helper
    def self.state_set_to_identifier(states)
      states.empty? ? Automaton::Finite::SINK_STATE : states.to_a.sort.join("")
    end
  end

end
