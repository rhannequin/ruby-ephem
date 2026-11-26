# frozen_string_literal: true

RSpec.describe Ephem::Core::Orientation do
  describe ".new" do
    it "exposes the three Euler angles" do
      orientation = described_class.new(1.0, 2.0, 3.0)

      expect(orientation.phi).to eq(1.0)
      expect(orientation.theta).to eq(2.0)
      expect(orientation.psi).to eq(3.0)
    end

    it "carries no rates by default" do
      orientation = described_class.new(1.0, 2.0, 3.0)

      expect(orientation.rates).to be_nil
      expect(orientation.rates?).to be(false)
    end

    it "carries rates when given" do
      orientation = described_class.new(1.0, 2.0, 3.0, rates: [0.1, 0.2, 0.3])

      expect(orientation.rates).to eq([0.1, 0.2, 0.3])
      expect(orientation.rates?).to be(true)
    end

    it "is frozen" do
      expect(described_class.new(1.0, 2.0, 3.0)).to be_frozen
    end

    it "raises for non-numeric angles" do
      expect { described_class.new(1.0, "x", 3.0) }.to raise_error(
        Ephem::InvalidInputError, "Orientation angles must be numeric"
      )
    end

    it "raises for malformed rates" do
      expect { described_class.new(1.0, 2.0, 3.0, rates: [0.1, 0.2]) }
        .to raise_error(
          Ephem::InvalidInputError, "Orientation rates must be three numerics"
        )
    end
  end

  describe "#[] and #to_a" do
    it "indexes angles and converts to an array" do
      orientation = described_class.new(1.0, 2.0, 3.0)

      expect(orientation.to_a).to eq([1.0, 2.0, 3.0])
      expect(orientation[0]).to eq(1.0)
      expect(orientation[2]).to eq(3.0)
    end

    it "raises for an invalid index" do
      expect { described_class.new(1.0, 2.0, 3.0)[3] }
        .to raise_error(Ephem::IndexError)
    end
  end

  describe "#to_matrix" do
    it "returns the identity for zero angles" do
      matrix = described_class.new(0.0, 0.0, 0.0).to_matrix

      expect(matrix).to eq(
        [[1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0]]
      )
    end

    it "composes the 3-1-3 sequence Rz(psi) * Rx(theta) * Rz(phi)" do
      phi = 0.3
      theta = 0.7
      psi = 1.1
      expected = Ephem::Core::Rotation.multiply(
        Ephem::Core::Rotation.about_z(psi),
        Ephem::Core::Rotation.about_x(theta),
        Ephem::Core::Rotation.about_z(phi)
      )

      expect(described_class.new(phi, theta, psi).to_matrix).to eq(expected)
    end

    it "is orthonormal" do
      matrix = described_class.new(1.2, 0.4, 5.9).to_matrix
      product = Ephem::Core::Rotation.multiply(matrix, matrix.transpose)

      product.each_with_index do |row, row_index|
        row.each_with_index do |value, column_index|
          expected = (row_index == column_index) ? 1.0 : 0.0
          expect(value).to be_within(1e-12).of(expected)
        end
      end
    end
  end

  describe "#==" do
    it "compares angles and rates" do
      with_rates = described_class.new(1.0, 2.0, 3.0, rates: [0.1, 0.2, 0.3])
      same_with_rates = described_class.new(
        1.0,
        2.0,
        3.0,
        rates: [0.1, 0.2, 0.3]
      )
      without_rates = described_class.new(1.0, 2.0, 3.0)

      expect(with_rates).to eq(same_with_rates)
      expect(with_rates).not_to eq(without_rates)
    end

    it "returns false for objects of another class" do
      orientation = described_class.new(1.0, 2.0, 3.0)

      expect(orientation == 5).to be(false)
      expect(orientation == [1.0, 2.0, 3.0]).to be(false)
    end

    it "returns false for nil" do
      orientation = described_class.new(1.0, 2.0, 3.0)

      # standard:disable Style/NilComparison
      expect(orientation == nil).to be(false)
      # standard:enable Style/NilComparison
    end

    it "supports Array#include? with mixed types" do
      orientation = described_class.new(1.0, 2.0, 3.0)
      mixed = [nil, 5, described_class.new(1.0, 2.0, 3.0)]

      expect(mixed.include?(orientation)).to be(true)
      expect([nil, 5].include?(orientation)).to be(false)
    end
  end

  describe "#eql?" do
    it "returns true for identical angles and rates" do
      orientation = described_class.new(1.0, 2.0, 3.0, rates: [0.1, 0.2, 0.3])
      same = described_class.new(1.0, 2.0, 3.0, rates: [0.1, 0.2, 0.3])

      expect(orientation.eql?(same)).to be(true)
    end

    it "returns false for numerically equal angles of another type" do
      integer_angles = described_class.new(1, 2, 3)
      float_angles = described_class.new(1.0, 2.0, 3.0)

      expect(integer_angles == float_angles).to be(true)
      expect(integer_angles.eql?(float_angles)).to be(false)
    end

    it "returns false for objects of another class" do
      orientation = described_class.new(1.0, 2.0, 3.0)

      expect(orientation.eql?(nil)).to be(false)
    end
  end

  describe "as a hash key" do
    it "looks up values by equal orientations" do
      lookup = {
        nil => :nothing,
        5 => :number,
        described_class.new(1.0, 2.0, 3.0, rates: [0.1, 0.2, 0.3]) => :rated,
        described_class.new(1.0, 2.0, 3.0) => :unrated
      }
      rated = described_class.new(1.0, 2.0, 3.0, rates: [0.1, 0.2, 0.3])
      unrated = described_class.new(1.0, 2.0, 3.0)

      expect(lookup[rated]).to eq(:rated)
      expect(lookup[unrated]).to eq(:unrated)
      expect(lookup[described_class.new(4.0, 5.0, 6.0)]).to be_nil
    end
  end

  describe "#inspect" do
    it "renders angles, and rates when present" do
      angles_only = described_class.new(1.0, 2.0, 3.0)
      with_rates = described_class.new(1.0, 2.0, 3.0, rates: [0.1, 0.2, 0.3])

      expect(angles_only.inspect)
        .to eq("Orientation[phi: 1.0, theta: 2.0, psi: 3.0]")
      expect(with_rates.inspect).to eq(
        "Orientation[phi: 1.0, theta: 2.0, psi: 3.0, rates: [0.1, 0.2, 0.3]]"
      )
    end
  end
end
