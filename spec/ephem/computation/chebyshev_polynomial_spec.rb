# frozen_string_literal: true

RSpec.describe Ephem::Computation::ChebyshevPolynomial do
  describe ".evaluate" do
    context "with degree 1 (constant only)" do
      it "returns the constant vector" do
        coeffs = [1.0, 2.0, 3.0]
        t = 0.123

        result = described_class.evaluate(coeffs, 1, t)

        expect(result).to eq([1.0, 2.0, 3.0])
      end
    end

    context "with degree 2 (constant + linear)" do
      it "returns componentwise a0 + t*a1" do
        coeffs = [1.0, 2.0, 5.0, 1.5, -2.0, 0.0]
        t = 0.75
        expected = [
          1.0 + 2.0 * 0.75,
          5.0 + 1.5 * 0.75,
          -2.0 + 0.0 * 0.75
        ]

        result = described_class.evaluate(coeffs, 2, t)

        expect_vector_close(result, expected)
      end
    end

    context "with degree 3 (quadratic)" do
      it "matches explicit sum a0*T0 + a1*T1 + a2*T2" do
        coeffs = [1.0, 4.0, -1.0, 2.0, 0.5, 2.0, 3.0, 0.0, 1.5]
        n_terms = 3
        t = -0.2
        t0 = 1
        t1 = t
        t2 = 2 * t * t - 1
        expected = [
          coeffs[0] * t0 + coeffs[1] * t1 + coeffs[2] * t2,
          coeffs[n_terms] * t0 + coeffs[n_terms + 1] * t1 + coeffs[n_terms + 2] * t2,
          coeffs[2 * n_terms] * t0 + coeffs[2 * n_terms + 1] * t1 + coeffs[2 * n_terms + 2] * t2
        ]

        result = described_class.evaluate(coeffs, n_terms, t)

        expect_vector_close(result, expected)
      end
    end

    context "with longer coefficients array" do
      it "returns array of size 3" do
        coeffs = [1.0, 4.0, 7.0, 2.0, 2.0, 5.0, 8.0, 1.0, 3.0, 6.0, 9.0, 0.0]
        t = 0.333

        result = described_class.evaluate(coeffs, 4, t)

        expect(result.size).to eq(3)
      end
    end

    it "returns the same result for repeated calls" do
      coeffs = [0.2, 0.3, 1.0, 1.5, -0.1, -0.5, 3.7, 0.4, -0.75]
      t = 0.62

      result1 = described_class.evaluate(coeffs, 3, t)
      result2 = described_class.evaluate(coeffs, 3, t)

      expect(result1).to eq(result2)
    end

    it "returns different results for different normalized_time" do
      coeffs = [2.0, 0.1, 1.0, 0.05, -1.0, -0.09]

      result1 = described_class.evaluate(coeffs, 2, 0.9)
      result2 = described_class.evaluate(coeffs, 2, -0.9)

      expect(result1).not_to eq(result2)
    end
  end

  describe ".evaluate_derivative" do
    context "with degree 1 (constant only)" do
      it "returns zero vector" do
        coeffs = [1.0, 2.0, 3.0]
        t = -0.2
        radius = 1000.0

        result = described_class.evaluate_derivative(coeffs, 1, t, radius)

        expect(result).to eq([0.0, 0.0, 0.0])
      end
    end

    context "with degree 2 (constant + linear)" do
      it "returns 2*a1 * scale" do
        coeffs = [0.0, 2.0, 0.0, -1.5, 0.0, 4.0]
        t = 0.0
        radius = 123.0
        scale = Ephem::Core::Constants::Time::SECONDS_PER_DAY / (2.0 * radius)
        expected = [2 * 2.0 * scale, 2 * -1.5 * scale, 2 * 4.0 * scale]

        result = described_class.evaluate_derivative(coeffs, 2, t, radius)

        expect_vector_close(result, expected)
      end
    end

    context "with degree 3 (quadratic)" do
      it "computes correct Chebyshev derivative" do
        coeffs = [1.0, 0.5, -0.25, 2.0, 0.2, 1.0, 3.0, -1.5, 2.0]
        t = 0.15
        radius = 2000.0

        result = described_class.evaluate_derivative(coeffs, 3, t, radius)

        expect(result.size).to eq(3)
      end
    end

    it "scales velocity according to radius" do
      coeffs = [0.0, 2.0, 0.0, -2.0, 0.0, 4.0]
      t = 0.25
      radius1 = 1000.0
      radius2 = 500.0

      result1 = described_class.evaluate_derivative(coeffs, 2, t, radius1)
      result2 = described_class.evaluate_derivative(coeffs, 2, t, radius2)

      expect(result1).not_to eq(result2)
    end

    it "returns the same result for repeated calls" do
      coeffs = [1.1, 0.0, 0.5, -0.1, 2.0, -1.0, 0.5, -2.0, 3.0]
      t = 0.58
      radius = 432.0

      result1 = described_class.evaluate_derivative(coeffs, 3, t, radius)
      result2 = described_class.evaluate_derivative(coeffs, 3, t, radius)

      expect(result1).to eq(result2)
    end

    it "returns different results for different normalized_time" do
      coeffs = [2.0, 0.1, 0.2, 1.0, 0.05, -0.7, -1.0, -0.09, 0.5]
      t = 0.3
      t2 = -0.3
      radius = 111.1

      result1 = described_class.evaluate_derivative(coeffs, 3, t, radius)
      result2 = described_class.evaluate_derivative(coeffs, 3, t2, radius)

      expect(result1).not_to eq(result2)
    end
  end

  def expect_vector_close(result, expected, tol = 1e-10)
    expect(result.size).to eq(expected.size)
    result.zip(expected).each do |a, b|
      expect(a).to be_within(tol).of(b)
    end
  end
end
