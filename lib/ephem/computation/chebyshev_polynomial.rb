# frozen_string_literal: true

require "numo/narray"

module Ephem
  module Computation
    class ChebyshevPolynomial
      include Core::Constants::Time

      def initialize(coefficients:, normalized_time:, radius: nil)
        @coefficients = coefficients
        @normalized_time = normalized_time
        @radius = radius
        @degree = @coefficients.shape[0]
        @dimension = @coefficients.shape[1]
        @two_times_normalized_time = 2.0 * @normalized_time
      end

      def evaluate
        polynomials = generate_polynomials(@degree, @dimension)
        combine_polynomials(polynomials)
      end

      def evaluate_derivative
        return Numo::DFloat.zeros(@dimension) if @degree < 2

        derivative = calculate_derivative(@degree, @dimension)
        scale_derivative(derivative)
      end

      private

      def generate_polynomials(degree, dimension)
        polynomials = initialize_polynomials(dimension)
        build_polynomial_sequence(polynomials, degree)
        polynomials
      end

      def initialize_polynomials(dimension)
        [
          Numo::DFloat.ones(dimension),
          @normalized_time * Numo::DFloat.ones(dimension)
        ]
      end

      def build_polynomial_sequence(polynomials, degree)
        (2...degree).each do |i|
          next_polynomial = compute_next_polynomial(
            polynomials[-2],
            polynomials[-1]
          )
          polynomials << next_polynomial
        end
      end

      def compute_next_polynomial(prev_prev, prev)
        2.0 * @normalized_time * prev - prev_prev
      end

      def combine_polynomials(polynomials)
        result = Numo::DFloat.zeros(@coefficients.shape[1])

        @coefficients.shape[0].times do |i|
          result += @coefficients[i, true] * polynomials[i]
        end

        result
      end

      def calculate_derivative(degree, dimension)
        derivative_prev = Numo::DFloat.zeros(dimension)
        derivative = derivative_prev.clone

        (degree - 1).downto(1) do |i|
          derivative_next = derivative.clone
          derivative = derivative_prev
          derivative_prev = calculate_derivative_term(
            @two_times_normalized_time,
            derivative,
            derivative_next,
            i
          )
        end

        derivative_prev
      end

      def calculate_derivative_term(two_t, deriv, deriv_next, index)
        two_t * deriv - deriv_next + @coefficients[index, true] * 2 * index
      end

      def scale_derivative(derivative)
        return derivative unless @radius
        derivative * (SECONDS_PER_DAY / (2 * @radius))
      end
    end
  end
end
