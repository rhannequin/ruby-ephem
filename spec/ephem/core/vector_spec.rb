# frozen_string_literal: true

RSpec.describe Ephem::Core::Vector do
  describe ".new" do
    it "creates a new vector with valid numeric inputs" do
      vector = described_class.new(1, 2, 3)

      expect(vector.x).to eq(1)
      expect(vector.y).to eq(2)
      expect(vector.z).to eq(3)
    end

    it "freezes the object" do
      vector = described_class.new(1, 2, 3)

      expect(vector).to be_frozen
    end

    it "raises InvalidInputError for non-numeric x" do
      expect { described_class.new("1", 2, 3) }.to raise_error(
        Ephem::InvalidInputError,
        "Vector components must be numeric"
      )
    end

    it "raises InvalidInputError for non-numeric y" do
      expect { described_class.new(1, "2", 3) }.to raise_error(
        Ephem::InvalidInputError,
        "Vector components must be numeric"
      )
    end

    it "raises InvalidInputError for non-numeric z" do
      expect { described_class.new(1, 2, "3") }.to raise_error(
        Ephem::InvalidInputError,
        "Vector components must be numeric"
      )
    end
  end

  describe ".[]" do
    it "creates a new vector using class method syntax" do
      vector = described_class[1, 2, 3]

      expect(vector).to be_a(described_class)
      expect(vector.to_a).to eq([1, 2, 3])
    end
  end

  describe "#+" do
    it "adds two vectors" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(4, 5, 6)

      result = vector1 + vector2

      expect(result.to_a).to eq([5, 7, 9])
      expect(result).to be_a(described_class)
      expect(result).not_to equal(vector1)
    end
  end

  describe "#-" do
    it "subtracts two vectors" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(4, 5, 6)

      result = vector1 - vector2

      expect(result.to_a).to eq([-3, -3, -3])
    end
  end

  describe "#*" do
    it "multiplies each component by the scalar" do
      vector = described_class.new(1, 2, 3)

      result = vector * 2

      expect(result).to be_a(described_class)
      expect(result.to_a).to eq([2, 4, 6])
    end

    it "multiplies by a float scalar" do
      vector = described_class.new(1.0, -2.0, 3.0)

      result = vector * 0.5

      expect(result.to_a).to eq([0.5, -1.0, 1.5])
    end

    it "does not mutate the original vector" do
      vector = described_class.new(1, 2, 3)

      _scaled = vector * 2

      expect(vector.to_a).to eq([1, 2, 3])
    end

    it "raises InvalidInputError for a non-numeric scalar" do
      vector = described_class.new(1, 2, 3)

      expect { vector * described_class.new(1, 2, 3) }.to raise_error(
        Ephem::InvalidInputError,
        "Can only multiply a Vector by a Numeric"
      )
    end
  end

  describe "#/" do
    it "divides each component by the scalar" do
      vector = described_class.new(2.0, 4.0, 6.0)

      result = vector / 2.0

      expect(result).to be_a(described_class)
      expect(result.to_a).to eq([1.0, 2.0, 3.0])
    end

    it "follows Ruby integer division for integer operands" do
      vector = described_class.new(3, 4, 5)

      result = vector / 2

      expect(result.to_a).to eq([1, 2, 2])
    end

    it "raises InvalidInputError for a non-numeric scalar" do
      vector = described_class.new(1, 2, 3)

      expect { vector / "2" }.to raise_error(
        Ephem::InvalidInputError,
        "Can only divide a Vector by a Numeric"
      )
    end
  end

  describe "#-@" do
    it "negates each component" do
      vector = described_class.new(1, -2, 3)

      result = -vector

      expect(result).to be_a(described_class)
      expect(result.to_a).to eq([-1, 2, -3])
    end
  end

  describe "#dot" do
    it "calculates dot product correctly" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(4, 5, 6)

      result = vector1.dot(vector2)

      expect(result).to eq(32) # (1*4 + 2*5 + 3*6)
    end
  end

  describe "#cross" do
    it "calculates cross product correctly" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(4, 5, 6)

      result = vector1.cross(vector2)

      expect(result.to_a).to eq([-3, 6, -3])
    end
  end

  describe "#magnitude" do
    it "calculates the magnitude correctly" do
      vector = described_class.new(3, 4, 0)

      result = vector.magnitude

      expect(result).to eq(5)
    end
  end

  describe "#[]" do
    it "accesses coordinates by index" do
      vector = described_class.new(1, 2, 3)

      expect(vector[0]).to eq(1)
      expect(vector[1]).to eq(2)
      expect(vector[2]).to eq(3)
    end

    it "raises IndexError for invalid index" do
      vector = described_class.new(1, 2, 3)

      expect { vector[3] }.to raise_error(::IndexError, "Invalid index: 3")
    end
  end

  describe "#to_a" do
    it "returns array representation" do
      vector = described_class.new(1, 2, 3)

      expect(vector.to_a).to eq([1, 2, 3])
    end
  end

  describe "#inspect and #to_s" do
    it "returns formatted string representation" do
      vector = described_class.new(1, 2, 3)

      expect(vector.inspect).to eq("Vector[1, 2, 3]")
      expect(vector.to_s).to eq("Vector[1, 2, 3]")
    end
  end

  describe "#hash" do
    it "returns consistent hash values for equal vectors" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(1, 2, 3)

      expect(vector1.hash).to eq(vector2.hash)
    end

    it "returns different hash values for different vectors" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(4, 5, 6)

      expect(vector1.hash).not_to eq(vector2.hash)
    end
  end

  describe "#==" do
    it "returns true for equal vectors" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(1, 2, 3)

      expect(vector1 == vector2).to be(true)
    end

    it "returns false for different vectors" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(4, 5, 6)

      expect(vector1 == vector2).to be(false)
    end

    it "returns false for objects of another class" do
      vector = described_class.new(1, 2, 3)

      expect(vector == 1).to be(false)
      expect(vector == [1, 2, 3]).to be(false)
    end

    it "returns false for nil" do
      vector = described_class.new(1, 2, 3)

      expect(vector == nil).to be(false) # standard:disable Style/NilComparison
    end

    it "treats numerically equal components as equal" do
      integer_vector = described_class.new(1, 2, 3)
      float_vector = described_class.new(1.0, 2.0, 3.0)

      expect(integer_vector == float_vector).to be(true)
    end

    it "supports Array#include? with mixed types" do
      vector = described_class.new(1, 2, 3)
      mixed = [nil, 1, "vector", described_class.new(1, 2, 3)]

      expect(mixed.include?(vector)).to be(true)
      expect([nil, 1, "vector"].include?(vector)).to be(false)
    end

    it "is equal to itself with NaN components" do
      vector = described_class.new(Float::NAN, 2, 3)
      same_vector = vector

      expect(vector == same_vector).to be(true)
      expect(vector.eql?(same_vector)).to be(true)
      expect([vector].include?(same_vector)).to be(true)
    end
  end

  describe "#eql?" do
    it "returns true for vectors with identical components" do
      vector1 = described_class.new(1, 2, 3)
      vector2 = described_class.new(1, 2, 3)

      expect(vector1.eql?(vector2)).to be(true)
    end

    it "returns false for numerically equal components of another type" do
      integer_vector = described_class.new(1, 2, 3)
      float_vector = described_class.new(1.0, 2.0, 3.0)

      expect(integer_vector.eql?(float_vector)).to be(false)
    end

    it "returns false for objects of another class" do
      vector = described_class.new(1, 2, 3)

      expect(vector.eql?(nil)).to be(false)
      expect(vector.eql?([1, 2, 3])).to be(false)
    end
  end

  describe "as a hash key" do
    it "looks up values by equal vectors" do
      lookup = {
        nil => :nothing,
        "origin" => :string,
        described_class.new(1, 2, 3) => :vector
      }

      expect(lookup[described_class.new(1, 2, 3)]).to eq(:vector)
      expect(lookup[described_class.new(4, 5, 6)]).to be_nil
    end
  end
end
