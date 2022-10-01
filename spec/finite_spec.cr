require "./spec_helper"

include Panini

describe Panini::Automaton::Deterministic do
  describe "#initialize" do

    context "with invalid start state" do
      it "raises ArgumentError", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1", '1' => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        expect_raises ArgumentError, "Invalid start state" do
          Automaton::Deterministic.new(states, symbols, transitions, "q11", Set{"q1"})
        end
      end
    end

    context "with invalid final state" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1", '1' => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        expect_raises ArgumentError, "Invalid accepting state(s)" do
          Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q11"})
        end
      end
    end

    context "with transitions containing invalid state" do
      it "raises ArgumentError", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1", '1' => "q11"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        expect_raises ArgumentError, "Invalid transition(s)" do
          Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        end
      end
    end

    context "with transitions containing invalid symbol" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1", '2' => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        expect_raises ArgumentError, "Invalid transition(s)" do
          Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        end
      end
    end

    context "with missing transitions" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        expect_raises ArgumentError, "Missing transition(s)" do
          Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        end
      end
    end
  end

  describe "#process" do
    context "input symbol" do
      it "moves to correct next state", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {"01".chars => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        dfa = Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.process('0')
        dfa.current.should eq "q2"

        dfa.reset
        dfa.process('1')
        dfa.current.should eq "q0"

        dfa.reset
        dfa.process('0').process('1')
        dfa.current.should eq "q1"
      end
    end

    context "sequence of input symbols" do
      it "moves to correct end state" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1", '1' => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        dfa = Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.accepts?("100101011010").should be_true
        dfa.current.should eq "q1"
      end
    end

  end

  describe "#accepts?" do
    context "valid sequence of input symbols starting with 0" do
      it "returns true" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1", '1' => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        dfa = Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.accepts?("00101011010").should be_true
      end
    end

    context "valid sequence of input symbols starting with 1" do
      it "returns true" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1", '1' => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        dfa = Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.accepts?("111101011010").should be_true
      end
    end

    context "invalid sequence of input symbols" do
      it "returns false" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => "q2", '1' => "q0"},
          "q1" => {'0' => "q1", '1' => "q1"},
          "q2" => {'0' => "q2", '1' => "q1"},
        }

        dfa = Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.accepts?("111111110000").should be_false
      end
    end
  end

  describe "#to_nfa" do
    it "generates an equivalent NFA from the DFA", focus: false do
      states = Set{"q0", "q1", "q2"}
      symbols = Set{'0', '1'}
      transitions = {
        "q0" => {'0' => "q2", '1' => "q0"},
        "q1" => {'0' => "q1", '1' => "q1"},
        "q2" => {'0' => "q2", '1' => "q1"},
      }

      dfa = Automaton::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
      nfa = dfa.to_nfa

      "01010".chars.each do |sym|
        dfa.process sym
        nfa.process sym
        nfa.current.should eq Set{dfa.current}
      end
    end
  end
end

describe Panini::Automaton::NonDeterministic do
  describe "#initialize" do
    context "when epsilon transitions are not present" do
      context "with invalid start state" do
        it "raises ArgumentError" do
          states = Set{"q0", "q1", "q2"}
          symbols = Set{'0', '1'}
          transitions = {
            "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
            "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
          }

          expect_raises ArgumentError, "Invalid start state" do
            Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q11"}, Set{"q2"})
          end
        end
      end

      context "with invalid final state" do
        it "raises ArgumentError" do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
          "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
          "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
        }

          expect_raises ArgumentError, "Invalid accepting state(s)" do
            Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q11"})
          end
        end
      end

      context "with transitions containing invalid state" do
        it "raises ArgumentError" do
          states = Set{"q0", "q1", "q2"}
          symbols = Set{'0', '1'}
          transitions = {
            "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
            "q1" => {'0' => Set{"q2"}, '1' => Set{"q11"}},
          }

          expect_raises ArgumentError, "Invalid transition(s)" do
            Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
          end
        end
      end

      context "with transitions containing invalid symbol" do
        it "raises ArgumentError" do
          states = Set{"q0", "q1", "q2"}
          symbols = Set{'0', '1'}
          transitions = {
            "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
            "q1" => {'0' => Set{"q2"}, '9' => Set{"q2"}},
          }

          expect_raises ArgumentError, "Invalid transition(s)" do
            Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
          end
        end
      end

    end

    context "when epsilon transitions are present" do
      context "with invalid start state" do
        it "raises ArgumentError" do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}, },
            "q4" => {'.' => Set{"q3"}},
          }

          expect_raises ArgumentError, "Invalid start state" do
            Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q11"}, Set{"q2"})
          end
        end
      end

      context "with invalid final state" do
        it "raises ArgumentError" do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}, },
            "q4" => {'.' => Set{"q3"}},
          }

          expect_raises ArgumentError, "Invalid accepting state(s)" do
            Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q11"})
          end
        end
      end

      context "with transitions containing invalid state" do
        it "raises ArgumentError" do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q11"}},
            "q4" => {'.' => Set{"q3"}},
          }

          expect_raises ArgumentError, "Invalid transition(s)" do
            Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q5"})
          end
        end
      end

      context "with transitions containing invalid symbol" do
        it "raises ArgumentError" do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q11"}},
            "q4" => {'.' => Set{"q3"}},
          }

          expect_raises ArgumentError, "Invalid transition(s)" do
            Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
          end
        end
      end

    end
  end

  describe "#epsilon_closure" do
    context "when epsilon transitions are not present" do
      it "gives a set containing a single state" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
          "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
        }

        nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        nfa.epsilon_closure("q0").should eq Set{"q0"}
      end
    end

    context "when epsilon transitions are present" do
      it "gives a set containing a single state", focus: false do
        states = Set{"1", "2", "3", "4", "5", "6", "7"}
        symbols = Set{'a', 'b'}
        transitions = {
          "1" => {Panini::EPSILON => Set{"2", "4"}},
          "2" => {Panini::EPSILON => Set{"3"}},
          "3" => {Panini::EPSILON => Set{"6"}},
          "4" => {'a' => Set{"5"}},
          "5" => {'b' => Set{"6"}, Panini::EPSILON => Set{"7"}},
        }

        nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"1"}, Set{"6"})
        nfa.epsilon_closure("1").should eq Set{"1", "2", "3", "4", "6"}
      end
    end
  end

  describe "#process" do
    context "when epsilon transitions are not present" do
      context "with input symbol", focus: false do
        it "moves to correct next state", focus: false do
          states = Set{"q0", "q1", "q2"}
          symbols = Set{'0', '1'}
          transitions = {
            "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
            "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
          nfa.process('0')
          nfa.current.should eq Set{"q0"}

          nfa.reset
          nfa.process('1')
          nfa.current.should eq Set{"q0", "q1"}

          nfa.reset
          nfa.process('0').process('1').process('0')
          nfa.current.should eq Set{"q0", "q2"}
        end
      end

      context "sequence of input symbols" do
        it "moves to correct end state", focus: false do
          states = Set{"q0", "q1", "q2"}
          symbols = Set{'0', '1'}
          transitions = {
            "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
            "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
          nfa.process("01010")
          nfa.current.should eq Set{"q0", "q2"}
        end
      end
    end

    context "when epsilon transitions are present" do
      context "input symbol" do
        it "moves to correct next state", focus: false do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}},
            "q4" => {'.' => Set{"q3"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q5"})

          nfa.process('7')
          nfa.current.should eq Set{"q1", "q4"}

          nfa.reset
          nfa.process('.')
          nfa.current.should eq Set{"q2"}

          nfa.reset
          nfa.process('+')
          nfa.current.should eq Set{"q1"}

          nfa.reset
          nfa.process('5').process('.').process('6')
          nfa.current.should eq Set{"q3", "q5"}
        end
      end

      context "sequence of input symbols" do
        it "moves to correct end state", focus: false do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}},
            "q4" => {'.' => Set{"q3"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q5"})
          nfa.process("5.6")
          nfa.current.should eq Set{"q3", "q5"}
        end
      end
    end

  end

  describe "#accepts?" do
    context "when epsilon transitions are not present" do
      context "valid sequence of input symbols starting with 0" do
        it "returns true", focus: false do
          states = Set{"q0", "q1", "q2"}
          symbols = Set{'0', '1'}
          transitions = {
            "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
            "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
          nfa.accepts?("01010").should be_true
        end
      end

      context "valid sequence of input symbols starting with 1" do
        it "returns true", focus: false do
          states = Set{"q0", "q1", "q2"}
          symbols = Set{'0', '1'}
          transitions = {
            "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
            "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
          nfa.accepts?("111101011010").should be_true
        end
      end

      context "invalid sequence of input symbols" do
        it "returns false", focus: false do
          states = Set{"q0", "q1", "q2"}
          symbols = Set{'0', '1'}
          transitions = {
            "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
            "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
          nfa.accepts?("111111110000").should be_false
        end
      end
    end

    context "when epsilon transitions are present", focus: false do
      context "for valid number with decimal" do
        it "returns true", focus: false do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}},
            "q4" => {'.' => Set{"q3"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q5"})
          nfa.accepts?("78.3").should be_true
        end
      end

      context "for number with no digits before decimal" do
        it "returns true", focus: false do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}},
            "q4" => {'.' => Set{"q3"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q5"})
          nfa.accepts?(".783").should be_true
        end
      end

      context "for number with no digits after decimal" do
        it "returns false", focus: false do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}},
            "q4" => {'.' => Set{"q3"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q5"})
          nfa.accepts?("783.").should be_true
        end
      end

      context "for an integer" do
        it "returns false", focus: false do
          states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
          symbols = "0123456789.+-".chars.to_set
          transitions = {
            "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
            "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
            "q2" => {"0123456789".chars => Set{"q3"}},
            "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}},
            "q4" => {'.' => Set{"q3"}},
          }

          nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q5"})
          nfa.accepts?("783").should be_false
        end
      end
    end
  end

  describe "#to_dfa" do
    context "from an NFA" do
      it "generates an equivalent DFA" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{'0', '1'}
        transitions = {
          "q0" => {'0' => Set{"q0"}, '1' => Set{"q0", "q1"}},
          "q1" => {'0' => Set{"q2"}, '1' => Set{"q2"}},
        }

        nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        dfa = nfa.to_dfa

        "01010".chars.each do |sym|
          nfa.process sym
          dfa.process sym
          dfa.current.should eq Panini::Automaton::Helper.state_set_to_identifier(nfa.current)
        end

        ["000010", "00000001000", "111111111"].each do |input|
          dfa.accepts?(input).should eq nfa.accepts?(input)
        end
      end
    end

    context "from an e-NFA" do
      it "generates an equivalent DFA", focus: false do
        states = Set{"q0", "q1", "q2", "q3", "q4", "q5"}
        symbols = "0123456789.+-".chars.to_set
        transitions = {
          "q0" => {"+-".chars => Set{"q1"}, Panini::EPSILON => Set{"q1"}},
          "q1" => {'.' => Set{"q2"}, "0123456789".chars => Set{"q1", "q4"}},
          "q2" => {"0123456789".chars => Set{"q3"}},
          "q3" => {"0123456789".chars => Set{"q3"}, Panini::EPSILON => Set{"q5"}},
          "q4" => {'.' => Set{"q3"}},
        }

        nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q5"})
        dfa = nfa.to_dfa

        "234.431".chars.each do |sym|
          nfa.process sym
          dfa.process sym
          dfa.current.should eq Panini::Automaton::Helper.state_set_to_identifier(nfa.current)
        end

        ["786", "786.", "7.86", ".786"].each do |input|
          dfa.accepts?(input).should eq nfa.accepts?(input)
        end
      end
    end
  end
end


describe Panini::Automaton do
  it "converts a NFA to DFA 1" do
    states = "pqr".split("").to_set
    symbols = "01".chars.to_set
    transitions = {
      "p" => {'0' => Set{"p", "q"}, '1' => Set{"p"}},
      "q" => {'1' => Set{"r"}},
      "r" => {'0' => Set{"p", "r"},'1' => Set{"q"}},
    }

    nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"p"}, Set{"r"})
    dfa = nfa.to_dfa

    ["00110", "01011000", "1100111", "110110"].each do |input|
      nfa.accepts?(input).should eq dfa.accepts?(input)
    end
  end

  it "converts a NFA to DFA 2" do
    states = "pqrs".split("").to_set
    symbols = "01".chars.to_set
    transitions = {
      "p" => {'0' => Set{"p", "r"}, '1' => Set{"q"}},
      "q" => {'0' => Set{"r", "s"}, '1' => Set{"p"}},
      "r" => {'0' => Set{"p", "s"}, '1' => Set{"r"}},
      "s" => {'0' => Set{"q", "r"}},
    }

    nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"p"}, Set{"r", "s"})
    dfa = nfa.to_dfa

    ["00110", "01011000", "1100111", "110110"].each do |input|
      nfa.accepts?(input).should eq dfa.accepts?(input)
    end
  end

  it "converts a NFA to DFA 3" do
    states = "pqrst".split("").to_set
    symbols = "01".chars.to_set
    transitions = {
      "p" => {'0' => Set{"p", "q"}, '1' => Set{"p"}},
      "q" => {'0' => Set{"r", "s"}, '1' => Set{"t"}},
      "r" => {'0' => Set{"p", "r"}, '1' => Set{"t"}},
    }

    nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"p"}, Set{"t", "s"})
    dfa = nfa.to_dfa

    ["00110", "01011000", "1100111", "110110"].each do |input|
      nfa.accepts?(input).should eq dfa.accepts?(input)
    end
  end

  it "converts an e-NFA to DFA 1", focus: false do
    states = "pqr".split("").to_set
    symbols = "ab".chars.to_set
    transitions = {
      "p" => {Panini::EPSILON => Set{"r"}, 'a' => Set{"q"}, 'b' => Set{"p", "r"}},
      "q" => {'a' => Set{"p"}},
      "r" => {Panini::EPSILON => Set{"p", "q"}, 'a' => Set{"r"}, 'b' => Set{"p"}},
    }

    e_nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"p"}, Set{"r"})
    dfa = e_nfa.to_dfa

    "baba".chars.each do |sym|
      e_nfa.process(sym)
      dfa.process(sym)

      dfa.current.should eq Panini::Automaton::Helper.state_set_to_identifier(e_nfa.current)
    end
  end

  it "converts an e-NFA to DFA 2", focus: false do
    states = "pqr".split("").to_set
    symbols = "abc".chars.to_set
    transitions = {
      "p" => {Panini::EPSILON => Set{"q", "r"}, 'b' => Set{"q"}, 'c' => Set{"r"}},
      "q" => {'a' => Set{"p"}, 'c' => Set{"p", "q"}, 'b' => Set{"r"}},
    }

    e_nfa = Automaton::NonDeterministic.new(states, symbols, transitions, Set{"p"}, Set{"r"})
    dfa = e_nfa.to_dfa

    "abbaca".chars.each do |sym|
      e_nfa.process(sym)
      dfa.process(sym)

      dfa.current.should eq Panini::Automaton::Helper.state_set_to_identifier(e_nfa.current)
    end
  end
end