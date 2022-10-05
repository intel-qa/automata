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

  describe "#initialize" do
    context "as array-like literal" do
      context "with a single symbol" do
        it "initializes a language of size 1", focus: false do
          lang_a = Lang.from "a"
          (lang_a.includes? "a").should be_true
          (lang_a.includes? "b").should be_false

          lang_a.min_string_size.should eq 1_u16
          lang_a.max_string_size.should eq 1_u16
        end
      end

      context "with a many symbols" do
        it "initializes a language of size 3" do
          lang_a = Lang.from "ab", "b", "1001"

          (lang_a.includes? "1001").should be_true
          (lang_a.includes? "101").should be_false
          (lang_a.includes? "ab").should be_true
          (lang_a.includes? "b").should be_true
          (lang_a.includes? "a").should be_false

          lang_a.min_string_size.should eq 1_u16
          lang_a.max_string_size.should eq 4_u16
        end
      end
    end

    context "with new" do
      context "with one symbol" do
        it "initializes a language of size 1" do
          lang_a = Language.from "a"
          (lang_a.includes? "a").should be_true
          (lang_a.includes? "b").should be_false

          lang_a.min_string_size.should eq 1_u16
          lang_a.max_string_size.should eq 1_u16
        end
      end

      context "with 3 symbols" do
        it "initializes a language of size 3" do
          a_lang = Language.from "ab", "b", "1001"
          (a_lang.includes? "1001").should be_true
          (a_lang.includes? "101").should be_false
          (a_lang.includes? "ab").should be_true
          (a_lang.includes? "a").should be_false

          a_lang.min_string_size.should eq 1_u16
          a_lang.max_string_size.should eq 4_u16
        end
      end

      context "with a block" do
        it "initializes a language of size infinity", focus: false do
          lang_1x = Lang.new(->(s : String) {s[-2] == '1'}, {'0', '1'}, 2)

          (lang_1x.includes? "10").should be_true
          (lang_1x.includes? "101").should be_false
          (lang_1x.includes? "1010110").should be_true
          (lang_1x.includes? "1010100").should be_false

          lang_1x.min_string_size.should eq 2_u16
          lang_1x.max_string_size.should eq Panini::Language::INFINITY
        end
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
        lang1 = Lang.new(->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)}, 1)
        lang2 = Lang.new(->(s : String) {s[0] == '1' && s[1..] == "0" * (s.size - 1)}, 1)

        lang_union = lang1 | lang2

        {"011111", "01", "0", "0111", "10000", "10", "1", "10000000000"}.each do |string|
          (lang_union.includes? string).should be_true
        end

        (lang_union.includes? "010").should be_false
      end
    end

    context "for a membered and a non-membered languages" do
      it "finds the union" do
        lang1 = Lang.from "10", "1010", "101010", "10101010", "1010101010"
        lang2 = Lang.new(->(s : String) {s[0] == '1' && s[1..] == "0" * (s.size - 1)}, 1)

        lang_union = lang1 | lang2

        {"101010", "10", "1010", "10000", "10", "1", "10000000000"}.each do |string|
          (lang_union.includes? string).should be_true
        end

        (lang_union.includes? "010").should be_false
      end
    end
  end

  describe "#+" do
    context "for 2 membered languages" do
      it "finds the concatenation" do
        lang_concat = (Lang.from "01", "0101", "010101", "01010101", "0101010101") + (Lang.from "10", "1010", "101010", "10101010", "1010101010")

        {"01011010", "01101010", "010101010110101010", "01011010101010", "0110", "010110", "0101011010101010", "010101011010", "010101010110"}.each do |string|
          (lang_concat.includes? string).should be_true
        end

        (lang_concat.includes? "010").should be_false
      end
    end

    context "for 2 non-membered languages" do
      it "finds the concatenation", focus: false do
        lang1 = Lang.new(
          ->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)},
          min_string_size: 1
        )

        # puts (lang1.includes? "0111")
        lang2 = Lang.new(->(s : String) {s[0] == '1' && s[1..] == "0" * (s.size - 1)}, 1)

        lang_concat = lang1 + lang2

        {"011111", "01", "0111", "010000", "01110", "0111111000", "010"}.each do |string|
          (lang_concat.includes? string).should be_true
        end

        {"1011111", "1000", "0001", "111", "000", "10101", "010101"}.each do |string|
          (lang_concat.includes? string).should be_false
        end
      end
    end

    context "for a membered and a non-membered languages" do
      it "finds the concatenation", focus: false do
        lang1 = Lang.from "10", "1010", "101010", "10101010", "1010101010"
        lang2 = Lang.new ->(s : String) {s[0] == '1' && s[1..] == "0" * (s.size - 1)}, alphabet: {'0', '1'}, min_string_size: 1

        lang_union = lang1 + lang2

        {"101000", "101", "101010100", "10101010"}.each do |string|
          (lang_union.includes? string).should be_true
        end

        {"10", "0110000", "1", "10000000000"}.each do |string|
          (lang_union.includes? string).should be_false
        end
      end
    end
  end

  describe "#**" do
    context "for a membered languages" do
      it "finds concatanation power" do
        lang = Lang.from "0", "1"
        lang_power = lang ** 7

        {"0101010", "0101001", "1100100", "0000100"}.each do |string|
          (lang_power.includes? string).should be_true
        end

        {"010101", "010100", "110010010", "00001001001"}.each do |string|
          (lang_power.includes? string).should be_false
        end
      end
    end

    context "for a non-membered language" do
      it "finds concatenation power", focus: false do
        lang = Lang.new ->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)}, alphabet: {'0', '1'}, min_string_size: 1
        lang_power = lang ** 3

        {"011110110111111", "0111111101110", "00101", "000111", "011100", "011011011", "000"}.each do |string|
          (lang_power.includes? string).should be_true
        end

        {"1011111", "1000", "10001", "111", "010100", "10101", "0101010"}.each do |string|
          (lang_power.includes? string).should be_false
        end
      end
    end
  end

  describe "#~" do
    context "for a membered languages" do
      it "finds language closure", focus: false do
        lang = Lang.from "0", "11"
        lang_closure = ~lang

        {"0110110", "011110011", "110011011000", "00001100110"}.each do |string|
          (lang_closure.includes? string).should be_true
        end
      end
    end

    context "for a non-membered language" do
      it "finds language closure", focus: false do
        lang = Lang.new ->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)}, alphabet: {'0', '1'}, min_string_size: 1
        lang_closure = ~lang

        {"01010", "011001", "01100101011000", "000010010"}.each do |string|
          (lang_closure.includes? string).should be_true
        end
      end
    end

    context "for a language closure" do
      it "finds its closure", focus: false do
        lang = Lang.new ->(s : String) {s[0] == '0' && s[1..] == "1" * (s.size - 1)}, alphabet: {'0', '1'}, min_string_size: 1
        closure_closure = ~~~lang

        {"01010", "011001", "01100101011000", "000010010"}.each do |string|
          (closure_closure.includes? string).should be_true
        end
      end
    end
  end
end
