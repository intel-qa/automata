require "./spec_helper"

include Panini

describe Panini::Finite::Deterministic do
  describe "#initialize" do

    context "with invalid start state" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "1" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        expect_raises ArgumentError, "Invalid start state" do
          Finite::Deterministic.new(states, symbols, transitions, "q11", Set{"q1"})
        end
      end
    end

    context "with invalid final state" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "1" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        expect_raises ArgumentError, "Invalid accepting state(s)" do
          Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q11"})
        end
      end
    end

    context "with transitions containing invalid state" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "1" => "q11"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        expect_raises ArgumentError, "Invalid transition(s)" do
          Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        end
      end
    end

    context "with transitions containing invalid symbol" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "2" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        expect_raises ArgumentError, "Invalid transition(s)" do
          Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        end
      end
    end

    context "with missing transitions" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        expect_raises ArgumentError, "Missing transition(s)" do
          Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        end
      end
    end
  end

  describe "#process" do
    context "input symbol" do
      it "moves to correct next state", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "1" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        dfa = Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.process("0")
        dfa.current.should eq "q2"

        dfa.reset
        dfa.process("1")
        dfa.current.should eq "q0"

        dfa.reset
        dfa.process("0").process("1")
        dfa.current.should eq "q1"
      end
    end

    context "sequence of input symbols" do
      it "moves to correct end state" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "1" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        dfa = Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.accepts?(["1","0","0","1","0","1","0","1","1","0","1","0",]).should be_true
        dfa.current.should eq "q1"
      end
    end

  end

  describe "#accepts?" do
    context "valid sequence of input symbols starting with 0" do
      it "returns true" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "1" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        dfa = Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.accepts?(["0","0","1","0","1","0","1","1","0","1","0",]).should be_true
      end
    end

    context "valid sequence of input symbols starting with 1" do
      it "returns true" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "1" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        dfa = Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.accepts?(["1","1","1","1","0","1","0","1","1","0","1","0",]).should be_true
      end
    end

    context "invalid sequence of input symbols" do
      it "returns false" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => "q2", "1" => "q0"},
          "q1" => {"0" => "q1", "1" => "q1"},
          "q2" => {"0" => "q2", "1" => "q1"},
        }

        dfa = Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
        dfa.accepts?(["1","1","1","1","1","1","1","1","0","0","0","0",]).should be_false
      end
    end
  end

  describe "#to_nfa" do
    it "generates an equivalent NFA from the DFA" do
      states = Set{"q0", "q1", "q2"}
      symbols = Set{"0", "1"}
      transitions = {
        "q0" => {"0" => "q2", "1" => "q0"},
        "q1" => {"0" => "q1", "1" => "q1"},
        "q2" => {"0" => "q2", "1" => "q1"},
      }

      dfa = Finite::Deterministic.new(states, symbols, transitions, "q0", Set{"q1"})
      nfa = dfa.to_nfa

      ["0", "1", "0", "1", "0"].each do |sym|
        dfa.process sym
        nfa.process sym
        nfa.current.should eq Set{dfa.current}
      end
    end
  end
end

describe Panini::Finite::NonDeterministic do
  describe "#initialize" do

    context "with invalid start state" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        expect_raises ArgumentError, "Invalid start state" do
          Finite::NonDeterministic.new(states, symbols, transitions, Set{"q11"}, Set{"q2"})
        end
      end
    end

    context "with invalid final state" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        expect_raises ArgumentError, "Invalid accepting state(s)" do
          Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q11"})
        end
      end
    end

    context "with transitions containing invalid state" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q11"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        expect_raises ArgumentError, "Invalid transition(s)" do
          Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        end
      end
    end

    context "with transitions containing invalid symbol" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "11" => Set{"q2"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        expect_raises ArgumentError, "Invalid transition(s)" do
          Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        end
      end
    end

    context "with missing transitions" do
      it "raises ArgumentError" do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
          "q2" => {"0" => Set(State).new},
        }

        expect_raises ArgumentError, "Missing transition(s)" do
          Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        end
      end
    end
  end

  describe "#process" do
    context "input symbol" do
      it "moves to correct next state", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        nfa = Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        nfa.process("0")
        nfa.current.should eq Set{"q0"}

        nfa.reset
        nfa.process("1")
        nfa.current.should eq Set{"q0", "q1"}

        nfa.reset
        nfa.process("0").process("1").process("0")
        nfa.current.should eq Set{"q0", "q2"}
      end
    end

    context "sequence of input symbols" do
      it "moves to correct end state", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        nfa = Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        nfa.process(["0","1","0","1","0"])
        nfa.current.should eq Set{"q0", "q2"}
      end
    end

  end

  describe "#accepts?" do
    context "valid sequence of input symbols starting with 0" do
      it "returns true", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        nfa = Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        nfa.accepts?(["0","1","0","1","0",]).should be_true
      end
    end

    context "valid sequence of input symbols starting with 1" do
      it "returns true", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        nfa = Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        nfa.accepts?(["1","1","1","1","0","1","0","1","1","0","1","0",]).should be_true
      end
    end

    context "invalid sequence of input symbols" do
      it "returns false", focus: false do
        states = Set{"q0", "q1", "q2"}
        symbols = Set{"0", "1"}
        transitions = {
          "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
          "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
          "q2" => {"0" => Set(State).new, "1" => Set(State).new},
        }

        nfa = Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
        nfa.accepts?(["1","1","1","1","1","1","1","1","0","0","0","0",]).should be_false
      end
    end
  end

  describe "#to_dfa" do
    it "generates an equivalent DFA from the NFA" do
      states = Set{"q0", "q1", "q2"}
      symbols = Set{"0", "1"}
      transitions = {
        "q0" => {"0" => Set{"q0"}, "1" => Set{"q0", "q1"}},
        "q1" => {"0" => Set{"q2"}, "1" => Set{"q2"}},
        "q2" => {"0" => Set(State).new, "1" => Set(State).new},
      }

      nfa = Finite::NonDeterministic.new(states, symbols, transitions, Set{"q0"}, Set{"q2"})
      dfa = nfa.to_dfa

      ["0", "1", "0", "1", "0"].each do |sym|
        nfa.process sym
        dfa.process sym
        dfa.current.should eq Panini.state_set_to_identifier(nfa.current)
      end
    end
  end
end
