require "string_pool"

require "./automaton"
require "./language"

# TODO: Write documentation for `Panini`
module Panini
  VERSION = "0.1.0"

  alias State = String

  #TODO: Use this pool for entire repo. remove any other pools being used
  POOL = StringPool.new
end
