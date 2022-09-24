require "./finite"

# TODO: Write documentation for `Panini`
module Panini
  VERSION = "0.1.0"

  alias State = String
  alias Token = String

  def self.state_set_to_identifier(states)
    states.to_a.sort.join("")
  end
end
