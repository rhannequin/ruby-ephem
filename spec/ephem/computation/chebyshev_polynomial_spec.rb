# frozen_string_literal: true

RSpec.describe Ephem::Computation::ChebyshevPolynomial do
  describe "#initialize" do
    it "raises error for non-NArray coefficients" do
      expect do
        described_class.new(
          coefficients: [[1, 1, 1]],
          normalized_time: 0.5
        )
      end.to raise_error(
        Ephem::InvalidInputError,
        "Coefficients must be a 2D Numo::NArray"
      )
    end

    it "raises error for 1D coefficients" do
      expect do
        described_class.new(
          coefficients: Numo::DFloat.cast([1, 1, 1]),
          normalized_time: 0.5
        )
      end.to raise_error(
        Ephem::InvalidInputError,
        "Coefficients must be a 2D Numo::NArray"
      )
    end

    it "raises error for normalized_time below -1" do
      coefficients = Numo::DFloat.cast([[1.0, 1.0, 1.0]])

      expect do
        described_class.new(
          coefficients: coefficients,
          normalized_time: -1.1
        )
      end.to raise_error(
        Ephem::InvalidInputError,
        "Normalized time must be in range [-1, 1]"
      )
    end

    it "raises error for normalized_time above 1" do
      coefficients = Numo::DFloat.cast([[1.0, 1.0, 1.0]])

      expect do
        described_class.new(
          coefficients: coefficients,
          normalized_time: 1.1
        )
      end.to raise_error(
        Ephem::InvalidInputError,
        "Normalized time must be in range [-1, 1]"
      )
    end
  end

  describe "#evaluate" do
    context "with degree 1" do
      it "returns correct evaluation for constant polynomial" do
        coefficients = Numo::DFloat.cast([[1.0, 1.0, 1.0]])
        polynomial = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5
        )

        result = polynomial.evaluate

        expect(result).to be_a(Numo::DFloat)
        expect(result.shape[0]).to eq(3)
        expect(result).to eq(Numo::DFloat[1.0, 1.0, 1.0])
      end
    end

    context "with degree 2" do
      it "returns correct evaluation for linear polynomial" do
        coefficients = Numo::DFloat.cast([
          [1.0, 1.0, 1.0],
          [2.0, 2.0, 2.0]
        ])
        polynomial = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5
        )

        result = polynomial.evaluate

        expected = coefficients[0, true] + coefficients[1, true] * 0.5
        expect(result).to be_within(1e-10).of(expected)
      end
    end

    context "with higher degree polynomials" do
      it "returns result with correct shape" do
        coefficients = Numo::DFloat.cast([
          [1.0, 1.0, 1.0],
          [2.0, 2.0, 2.0],
          [3.0, 3.0, 3.0]
        ])
        polynomial = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5
        )

        result = polynomial.evaluate

        expect(result).to be_a(Numo::DFloat)
        expect(result.shape[0]).to eq(3)
      end

      it "returns consistent results on multiple evaluations" do
        coefficients = Numo::DFloat.cast([
          [1.0, 1.0, 1.0],
          [2.0, 2.0, 2.0],
          [3.0, 3.0, 3.0]
        ])
        polynomial = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5
        )

        first_result = polynomial.evaluate
        second_result = polynomial.evaluate

        expect(first_result).to eq(second_result)
      end

      it "returns different results for different normalized times" do
        coefficients = Numo::DFloat.cast([
          [1.0, 1.0, 1.0],
          [2.0, 2.0, 2.0],
          [3.0, 3.0, 3.0]
        ])

        result1 = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5
        ).evaluate
        result2 = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.6
        ).evaluate

        expect(result1).not_to eq(result2)
      end
    end
  end

  describe "#evaluate_derivative" do
    context "with degree < 2" do
      it "returns zero array" do
        coefficients = Numo::DFloat.cast([[1.0, 1.0, 1.0]])
        polynomial = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5,
          radius: 1000.0
        )

        result = polynomial.evaluate_derivative

        expect(result).to eq(Numo::DFloat.zeros(3))
      end
    end

    context "with degree >= 2" do
      it "returns result with correct shape" do
        coefficients = Numo::DFloat.cast([
          [1.0, 1.0, 1.0],
          [2.0, 2.0, 2.0],
          [3.0, 3.0, 3.0]
        ])
        polynomial = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5,
          radius: 1000.0
        )

        result = polynomial.evaluate_derivative

        expect(result).to be_a(Numo::DFloat)
        expect(result.shape[0]).to eq(3)
      end

      it "returns consistent derivative results when evaluating multiple times" do
        coefficients = Numo::DFloat.cast([
          [1.0, 1.0, 1.0],
          [2.0, 2.0, 2.0],
          [3.0, 3.0, 3.0]
        ])
        polynomial = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5,
          radius: 1000.0
        )

        polynomial.evaluate
        first_derivative = polynomial.evaluate_derivative
        second_derivative = polynomial.evaluate_derivative

        expect(first_derivative).to eq(second_derivative)
      end

      it "scales derivative with radius" do
        coefficients = Numo::DFloat.cast([
          [1.0, 1.0, 1.0],
          [2.0, 2.0, 2.0],
          [3.0, 3.0, 3.0]
        ])

        result_with_radius = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5,
          radius: 1000.0
        ).evaluate_derivative
        result_without_radius = described_class.new(
          coefficients: coefficients,
          normalized_time: 0.5,
          radius: nil
        ).evaluate_derivative

        expect(result_with_radius).not_to eq(result_without_radius)
      end
    end
  end
end
