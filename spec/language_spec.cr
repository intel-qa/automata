require "./spec_helper"

describe Panini::Alphabet do
  describe "#defines?" do
    context "for a string defined over the alphabet" do
      it "returns true" do
        alphabet = Alphabet.from '0', '1'
        (alphabet.defines? "101011001").should be_true
      end
    end

    context "for a string not defined over the alphabet" do
      it "returns false" do
        alphabet = Alphabet.from '0', '1'
        (alphabet.defines? "1010711001").should be_false
      end
    end

    context "for epsilon string" do
      it "returns true" do
        alphabet = Alphabet.from '0', '1'
        (alphabet.defines? Alphabet::EPSILON).should be_true
      end
    end
  end

  describe "#**" do
    context "with exponent as 0" do
      it "generates all string of length 0" do
        alphabet = Alphabet.from '0', '1'
        (alphabet ** 0).should eq Set{""}
      end
    end

    context "with exponent as 1" do
      it "generates all string of length 1" do
        alphabet = Alphabet.from '0', '1'
        (alphabet ** 1).should eq Set{"0", "1"}
      end
    end

    context "with exponent as 3" do
      it "generates all string of length 3" do
        alphabet = Alphabet.from '0', '1'
        (alphabet ** 3).should eq Set{"000", "001", "010", "100", "011", "101", "110", "111"}
      end
    end
  end
end

describe Panini::Language do
  describe "::PHI" do
    it "PHI does not include any string" do
      (Lang::PHI.includes? "1").should be_false
    end
  end

  describe "::EPSILON" do
    it "EPSILON includes only epsilon symbol" do
      (Lang::EPSILON.includes? "").should be_true
      (Lang::EPSILON.includes? "1").should be_false
    end
  end

  describe ".from" do
    context "strings" do
      it "creates a new language" do
        lang_a = Lang.from "ab", "b", "1001"

        (lang_a.includes? "1001").should be_true
        (lang_a.includes? "101").should be_false
        (lang_a.includes? "ab").should be_true
        (lang_a.includes? "b").should be_true
        (lang_a.includes? "a").should be_false
      end
    end

    context "criterion" do
      it "initializes a language", focus: false do
        lang_1x = Lang.from ->(s : String) {s.size > 1 && s[-2] == '1' && s.chars.all?{|c| c == '0' || c == '1' }}

        (lang_1x.includes? "10").should be_true
        (lang_1x.includes? "101").should be_false
        (lang_1x.includes? "1010110").should be_true
        (lang_1x.includes? "1010100").should be_false
      end
    end

    context "symbols" do
      it "initializes a language", focus: false do
        lang_1x = Lang.from '0', '1'

        (lang_1x.includes? "10").should be_true
        (lang_1x.includes? "101").should be_true
        (lang_1x.includes? "1010110").should be_true
        (lang_1x.includes? "10100").should be_true
      end
    end
  end

  describe "#|" do
    context "for 2 membered languages" do
      it "finds the union" do
        lang_union = (Lang.from "01", "0101", "010101", "01010101", "0101010101") | (Lang.from "10", "1010", "101010", "10101010", "1010101010")

        {"10", "1010", "101010", "10101010", "1010101010", "01", "0101", "010101", "01010101", "0101010101"}.each do |string|
          (lang_union.includes? string).should be_true
        end

        (lang_union.includes? "010").should be_false
      end
    end

    context "for 2 non-membered languages" do
      it "finds the union" do
        lang1 = Lang.new(
          min_size: 1,
          criterion: ->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)}
        )
        lang2 = Lang.new(
          min_size: 1,
          criterion: ->(s : String) {s[0] == '1' && s[1..] == "0" * (s.size - 1)}
        )

        lang_union = lang1 | lang2

        {"011111", "01", "0", "0111", "10000", "10", "1", "10000000000"}.each do |string|
          (lang_union.includes? string).should be_true
        end

        (lang_union.includes? "truetrue010").should be_false
      end
    end

    context "for a membered and a non-membered languages", focus: false do
      it "finds the union" do
        lang1 = Lang.from "10", "1010", "101010", "10101010", "1010101010"
        lang2 = Lang.new(
          criterion: ->(s : String) {s[0] == '1' && s[1..] == "0" * (s.size - 1)},
          min_size: 1
        )

        lang_union = lang1 | lang2

        {"101010", "10", "1010", "10000", "10", "1", "10000000000"}.each do |string|
          (lang_union.includes? string).should be_true
        end

        (lang_union.includes? "010").should be_false
      end
    end
  end

  describe "#+" do
    context "for 2 languages with membership" do
      it "finds the concatenation" do
        lang_concat = (Lang.from "01", "0101", "010101", "01010101", "0101010101") + (Lang.from "10", "1010", "101010", "10101010", "1010101010")

        {"01011010", "01101010", "010101010110101010", "01011010101010", "0110", "010110", "0101011010101010", "010101011010", "010101010110"}.each do |string|
          (lang_concat.includes? string).should be_true
        end

        (lang_concat.includes? "010").should be_false
      end
    end

    context "for 2 languages with criterion", focus: false do
      it "finds the concatenation", focus: false do
        lang1 = Lang.new(
          criterion: ->(s : String) {s.size > 0 && s[0] == '0' && s[1..] == "1" * (s.size - 1)},
          min_size: 1
        )

        lang2 = Lang.new(
          criterion: ->(s : String) {s.size > 0 && s[0] == '1' && s[1..] == "0" * (s.size - 1)},
          min_size: 1
        )

        lang_concat = lang1 + lang2

        {"011111", "01", "0111", "010000", "01110", "0111111000", "010"}.each do |string|
          (lang_concat.includes? string).should be_true
        end

        {"1011111", "1000", "0001", "111", "000", "10101", "010101"}.each do |string|
          (lang_concat.includes? string).should be_false
        end
      end
    end

    context "for a membership language and a criterion language", focus: false do
      it "finds the concatenation", focus: false do
        lang1 = Lang.from "10", "1010", "101010", "10101010", "1010101010"
        lang2 = Lang.new(
          criterion: ->(s : String) {s[0] == '1' && s[1..] == "0" * (s.size - 1)},
          min_size: 1
        )

        lang_concat = lang1 + lang2

        {"101000", "101", "101010100", "10101010"}.each do |string|
          (lang_concat.includes? string).should be_true
        end

        {"10", "0110000", "1", "10000000000"}.each do |string|
          (lang_concat.includes? string).should be_false
        end
      end
    end

    context "for an epsilon membership language and a criterion language", focus: false do
      it "finds the concatenation", focus: false do
        lang1 = Lang.from "", "10", "1010", "101010", "10101010", "1010101010"

        lang2 = Lang.new(
          criterion: ->(s : String) {s[0] == '1' && s[1..] == "0" * (s.size - 1)},
          min_size: 1
        )

        lang_concat = lang1 + lang2

        {"1000", "101000", "101", "101010100", "10101010"}.each do |string|
          (lang_concat.includes? string).should be_true
        end

        {"01010", "0110000", "1001", "100001000000"}.each do |string|
          (lang_concat.includes? string).should be_false
        end
      end
    end

    context "for a membership language and an epsilon criterion language", focus: false do
      it "finds the concatenation", focus: false do
        lang1 = Lang.from "10", "1010", "101010", "10101010", "1010101010"
        lang2 = Lang.from ->(s : String) {s.size == 0 || s[0] == '0' && s[1..] == "1" * (s.size - 1)}

        lang_concat = lang1 + lang2

        {"10", "100111", "100", "101010100", "10101010"}.each do |string|
          (lang_concat.includes? string).should be_true
        end


        {"01010", "0110000", "10101", "100001000000"}.each do |string|
          (lang_concat.includes? string).should be_false
        end
      end
    end

    context "for an epsilon membership language and an epsilon criterion language", focus: false do
      it "finds the concatenation", focus: false do
        lang1 = Lang.from "", "10", "1010", "101010", "10101010", "1010101010"
        lang2 = Lang.from ->(s : String) {s.size == 0 || s[0] == '1' && s[1..] == "0" * (s.size - 1)}

        lang_concat = lang1 + lang2

        {"", "10", "101000", "101", "101010100", "10101010"}.each do |string|
          (lang_concat.includes? string).should be_true
        end

        {"0110000", "1001", "100001000000"}.each do |string|
          (lang_concat.includes? string).should be_false
        end
      end
    end
  end

  describe "#**", focus: false do
    context "for a language with membership", focus: false do
      it "finds concatanation power > 1" do
        lang = Lang.from "1", "10", "100", "1000"
        lang_power = lang ** 3

        {"110001", "1101000", "1000110", "10010100", "1011"}.each do |string|
          (lang_power.includes? string).should be_true
        end

        {"", "0101010", "0101001", "110010010", "0000100", "1111"}.each do |string|
          (lang_power.includes? string).should be_false
        end
      end

      it "finds concatanation power = 1" do
        lang = Lang.from "1", "10", "100", "1000"
        lang_power = lang ** 1

        {"1", "1000", "10", "100"}.each do |string|
          (lang_power.includes? string).should be_true
        end

        {"", "11", "010", "101", "105"}.each do |string|
          (lang_power.includes? string).should be_false
        end
      end

      it "finds concatanation power = 0" do
        lang = Lang.from "1", "10", "100", "1000"
        lang_power = lang ** 0

        (lang_power.includes? "").should be_true
        (lang_power.includes? "10").should be_false
      end
    end

    context "for an epsilon membership language", focus: false do
      it "finds concatanation power > 1" do
        lang = Lang.from "", "1", "10", "100", "1000"
        lang_power = lang ** 3

        {"111", "110001", "10001010", "100101"}.each do |string|
          (lang_power.includes? string).should be_true
        end

        {"0101010", "0101001", "1010101", "110110", "1111"}.each do |string|
          (lang_power.includes? string).should be_false
        end
      end
    end

    context "for a epsilon-language with criterion" do
      it "finds concatenation power > 1", focus: false do
        lang = Lang.new(
          criterion: ->(s : String) {s.size == 0 || s[0] == '0' && s[1..] == "1" * (s.size - 1)},
          alphabets: {'0', '1'}
        )
        lang_power = lang ** 3

        {"011110110111111", "0111101101", "01010", "011010111", "0111010", "011011011"}.each do |string|
          (lang_power.includes? string).should be_true
        end

        {"1000", "10001", "111", "010100", "01000", "0101010"}.each do |string|
          (lang_power.includes? string).should be_false
        end
      end
    end
  end

  describe "#~" do
    context "for a membered languages" do
      it "finds language closure", focus: false do
        lang = Lang.from "", "0", "11"
        lang_closure = ~lang

        {"", "0110110", "011110011", "110011011000", "00001100110"}.each do |string|
          (lang_closure.includes? string).should be_true
        end

        {"0111010", "011001", "100101000", "111010010"}.each do |string|
          (lang_closure.includes? string).should be_false
        end
      end
    end

    context "for a non-membered language" do
      it "finds language closure", focus: false do
        lang = Lang.new(
          criterion: ->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)},
          alphabets: {'0', '1'},
          min_size: 1
        )
        lang_closure = ~lang

        {"", "01010", "011001", "01100101011000", "000010010"}.each do |string|
          (lang_closure.includes? string).should be_true
        end
      end
    end

    context "for a language closure" do
      it "finds its recursive closure", focus: false do
        lang = Lang.new(
          criterion: ->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)},
          min_size: 1
        )
        recurive_closure = ~~~~~~~lang

        {"", "01010", "011001", "01100101011000", "000010010"}.each do |string|
          (recurive_closure.includes? string).should be_true
        end
      end
    end
  end

  describe "#words", focus: false do
    context "for a language not having alphabet inclusion type" do
      it "raises exception" do
        expect_raises Language::AlphabetNotFoundError do
          Lang::PHI.words(size: 3)
        end

        expect_raises Language::AlphabetNotFoundError do
          Lang::EPSILON.words(size: 3)
        end
      end
    end

    context "for a language having alphabet inclusion type" do
      it "generates words of a given length from a language" do
        lang = Lang.new(
          criterion: ->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)},
          alphabets: {'0', '1'},
          min_size: 1
        )

        lang.words(size: 3).should eq Set{"011"}
      end
    end
  end

  describe "#regular?" do
    context "for Lang::PHI" do
      it "detects as regular language" do
        Lang::PHI.regular?.should be_true
      end
    end

    context "for Lang::EPSILON" do
      it "detects as regular language" do
        Lang::EPSILON.regular?.should be_true
      end
    end

    context "for Language with single symbol" do
      it "detects as regular language" do
        (Lang.from "a").regular?.should be_true
      end
    end

    context "for a union of regular languages" do
      it "detects as regular language" do
        ((Lang.from "a") | Lang.from "b").regular?.should be_true
      end
    end

    context "for a concatenation of regular languages" do
      it "detects as a regular language" do
        ((Lang.from "a") + Lang.from "b").regular?.should be_true
      end
    end

    context "for a closure of regular language" do
      it "detects as a regular language" do
        (~(Lang.from "a")).regular?.should be_true
      end
    end

  end

  describe "#to_nfa" do
    context "for Lang::PHI" do
      it "generates an phi basis NFA" do
        phi_nfa = Lang::PHI.to_nfa
        (phi_nfa.accepts? Alphabet::EPSILON).should be_false
        (phi_nfa.accepts? "a").should be_false
      end
    end

    context "for Lang::EPSILON" do
      it "generates an epsilon basis NFA" do
        epsilon_nfa = Lang::EPSILON.to_nfa
        (epsilon_nfa.accepts? Alphabet::EPSILON).should be_true
        (epsilon_nfa.accepts? "a").should be_false
      end
    end

    context "for Language with single symbol" do
      it "generates an symbol basis NFA" do
        symbol_nfa = (Lang.from "a").to_nfa
        (symbol_nfa.accepts? Alphabet::EPSILON).should be_false
        (symbol_nfa.accepts? "a").should be_true
      end
    end

    context "for union Language" do
      it "generates union NFA", focus: false do
        union_nfa = ((Lang.from "a") | (Lang.from "b")).to_nfa

        (union_nfa.accepts? Alphabet::EPSILON).should be_false

        (union_nfa.accepts? "a").should be_true
        (union_nfa.accepts? "b").should be_true
      end
    end

    context "for concat Language" do
      it "generates concat NFA", focus: false do
        concat_nfa = ((Lang.from "a") + (Lang.from "b")).to_nfa

        (concat_nfa.accepts? Alphabet::EPSILON).should be_false
        (concat_nfa.accepts? "b").should be_false
        (concat_nfa.accepts? "a").should be_false

        (concat_nfa.accepts? "ab").should be_true
      end
    end

    context "for closure Language" do
      it "generates closure NFA", focus: false do
        closure_nfa = (~(Lang.from "a")).to_nfa

        (closure_nfa.accepts? Alphabet::EPSILON).should be_true
        (closure_nfa.accepts? "b").should be_false
        (closure_nfa.accepts? "a").should be_true

        (closure_nfa.accepts? "aa").should be_true
        (closure_nfa.accepts? "ab").should be_false

        (closure_nfa.accepts? "aaaaaaaaa").should be_true
      end
    end
  end

end

describe "Regular Languages", focus: false do
  # TODO: benchmark code: dfa accpets very quickly compared to nfa, so converting to dfa before checking acceptance
  it "converts 110(0 + 1)* to nfa", focus: false do
    l110x = ((Lang.from "1") + (Lang.from "1") + (Lang.from "0") + ~((Lang.from "0") | (Lang.from "1")))
    match = "11010101"

    nfa_accepts = l110x.to_nfa.to_dfa.accepts? match
    language_includes = l110x.includes? match

    nfa_accepts.should be_true
    language_includes.should be_true
  end

  it "converts (0 + 1)*1011(0 + 1)* to nfa", focus: false do
    lx1011x = ~((Lang.from "0") | (Lang.from "1")) + (Lang.from "1") + (Lang.from "0") + (Lang.from "1") + (Lang.from "1") + ~((Lang.from "0") | (Lang.from "1"))
    match = "101111000101110100"

    dfa_accepts = lx1011x.to_nfa.to_dfa.accepts? match
    language_includes = lx1011x.includes? match

    dfa_accepts.should be_true
    language_includes.should be_true
  end
end