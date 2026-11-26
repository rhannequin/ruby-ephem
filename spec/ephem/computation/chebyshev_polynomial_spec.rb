# frozen_string_literal: true

RSpec.describe Ephem::Computation::ChebyshevPolynomial do
  describe ".evaluate" do
    it "returns the constant term of a degree 0 polynomial" do
      coefficients = [[1.0, 2.0, 3.0]]

      result = described_class.evaluate(coefficients, 0.123)

      expect(result).to eq([1.0, 2.0, 3.0])
    end

    it "evaluates a degree 1 polynomial" do
      coefficients = [
        [1.0, 5.0, -2.0],
        [2.0, 1.5, 0.0]
      ]

      result = described_class.evaluate(coefficients, 0.75)

      expect_components_close(result, [2.5, 6.125, -2.0])
    end

    it "evaluates a degree 2 polynomial" do
      coefficients = [
        [1.0, 2.0, 3.0],
        [4.0, 0.5, 0.0],
        [-1.0, 2.0, 1.5]
      ]
      normalized_time = -0.2

      result = described_class.evaluate(coefficients, normalized_time)

      expected = coefficients.transpose.map do |component_coefficients|
        chebyshev_sum(component_coefficients, normalized_time)
      end
      expect_components_close(result, expected)
    end

    it "evaluates a degree 3 polynomial" do
      coefficients = [
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
        [7.0, 8.0, 9.0],
        [2.0, 1.0, 0.0]
      ]
      normalized_time = 0.333

      result = described_class.evaluate(coefficients, normalized_time)

      expected = coefficients.transpose.map do |component_coefficients|
        chebyshev_sum(component_coefficients, normalized_time)
      end
      expect_components_close(result, expected)
    end
  end

  describe ".evaluate_with_derivative" do
    it "returns a zero velocity for a degree 0 polynomial" do
      position, velocity =
        described_class.evaluate_with_derivative([[1.0, 2.0, 3.0]], 0.3, 100.0)

      expect(position).to eq([1.0, 2.0, 3.0])
      expect(velocity).to eq([0.0, 0.0, 0.0])
    end

    it "returns the linear term scaled to units per day" do
      coefficients = [
        [0.0, 0.0, 0.0],
        [2.0, -1.5, 4.0]
      ]
      radius = 123.0

      _position, velocity =
        described_class.evaluate_with_derivative(coefficients, 0.0, radius)

      expected = [2.0, -1.5, 4.0].map do |coefficient|
        coefficient * seconds_per_day / radius
      end
      expect_components_close(velocity, expected)
    end

    it "evaluates position and velocity of a degree 3 polynomial" do
      coefficients = [
        [1.0, 2.0, 3.0],
        [0.5, 0.2, -1.5],
        [-0.25, 1.0, 2.0],
        [0.1, -0.4, 0.7]
      ]
      radius = 2000.0

      [-1.0, -0.3, 0.0, 0.42, 1.0].each do |normalized_time|
        position, velocity = described_class.evaluate_with_derivative(
          coefficients, normalized_time, radius
        )

        components = coefficients.transpose
        expected_position = components.map do |component_coefficients|
          chebyshev_sum(component_coefficients, normalized_time)
        end
        expected_velocity = components.map do |component_coefficients|
          chebyshev_derivative(component_coefficients, normalized_time) *
            seconds_per_day / radius
        end
        expect_components_close(position, expected_position)
        expect_components_close(velocity, expected_velocity)
      end
    end

    it "returns the same position as .evaluate" do
      coefficients = [
        [0.2, 1.5, 3.7],
        [0.3, -0.1, 0.4],
        [1.0, -0.5, -0.75]
      ]

      position, _velocity =
        described_class.evaluate_with_derivative(coefficients, 0.62, 432.0)

      expect(position).to eq(described_class.evaluate(coefficients, 0.62))
    end

    it "halves the velocity when the interval radius doubles" do
      coefficients = [
        [0.0, 0.0, 0.0],
        [2.0, -2.0, 4.0]
      ]

      _position, short_velocity =
        described_class.evaluate_with_derivative(coefficients, 0.25, 500.0)
      _position, long_velocity =
        described_class.evaluate_with_derivative(coefficients, 0.25, 1000.0)

      halved = short_velocity.map { |component| component / 2.0 }
      expect_components_close(long_velocity, halved)
    end
  end

  def chebyshev_sum(component_coefficients, normalized_time)
    component_coefficients.each_with_index.sum do |coefficient, degree|
      coefficient * Math.cos(degree * Math.acos(normalized_time))
    end
  end

  def chebyshev_derivative(component_coefficients, normalized_time)
    first, second, third = component_coefficients.drop(1)
    first +
      second * 4.0 * normalized_time +
      third * (12.0 * normalized_time**2 - 3.0)
  end

  def seconds_per_day
    Ephem::Core::Constants::Time::SECONDS_PER_DAY
  end

  def expect_components_close(actual, expected, tolerance = 1e-10)
    expect(actual.size).to eq(expected.size)
    actual.zip(expected).each do |actual_component, expected_component|
      expect(actual_component).to be_within(tolerance).of(expected_component)
    end
  end
end
