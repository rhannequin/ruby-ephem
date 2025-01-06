# frozen_string_literal: true

require "numo/narray"

module Ephem
  module Computation
    # Implements Chebyshev polynomial evaluation and differentiation for
    # astronomical calculations.
    #
    # Chebyshev polynomials are mathematical functions that can be used to
    # approximate other functions with high accuracy. In astronomical
    # calculations, they are used to approximate positions and velocities of
    # celestial bodies.
    #
    # The polynomial evaluation is done using the Clenshaw algorithm, which is
    # numerically stable and efficient. For performance optimization, polynomial
    # values are cached when they need to be used both for position and velocity
    # calculations.
    #
    # @example Calculating position in 3D space
    #   # coefficients is a 2D array where:
    #   # - First dimension is the polynomial degree (n terms)
    #   # - Second dimension is the spatial dimension (3 for x,y,z)
    #   coefficients = Numo::DFloat.cast([[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]])
    #
    #   # normalized_time must be between -1 and 1
    #   polynomial = ChebyshevPolynomial.new(
    #     coefficients: coefficients,
    #     normalized_time: 0.5
    #   )
    #
    #   position = polynomial.evaluate
    #
    # @example Calculating velocity with time scaling
    #   # radius is the time span in days
    #   polynomial = ChebyshevPolynomial.new(
    #     coefficients: coefficients,
    #     normalized_time: 0.5,
    #     radius: 32.0  # 32-day time span
    #   )
    #
    #   velocity = polynomial.evaluate_derivative
    class ChebyshevPolynomial
      include Core::Constants::Time

      # Initializes a new Chebyshev polynomial calculator
      #
      # @param coefficients [Numo::NArray] 2D array of Chebyshev polynomial
      #   coefficients. First dimension represents polynomial terms
      #   (degree + 1). Second dimension represents spatial components
      #   (usually 3 for x,y,z)
      # @param normalized_time [Float] Time parameter normalized to [-1, 1]
      #   interval
      # @param radius [Float, nil] Optional scaling factor for derivative
      #   calculations, usually represents the time span of the interval in days
      #
      # @raise [Ephem::InvalidInputError] if coefficients are not a 2D
      #   Numo::NArray
      # @raise [Ephem::InvalidInputError] if normalized_time is outside [-1, 1]
      def initialize(coefficients:, normalized_time:, radius: nil)
        validate_inputs(coefficients, normalized_time)

        @coefficients = coefficients
        @normalized_time = normalized_time
        @radius = radius
        @degree = @coefficients.shape[0]
        @dimension = @coefficients.shape[1]
        @two_times_normalized_time = 2.0 * @normalized_time
        @polynomials = nil # Cache for polynomial values
      end

      # Evaluates the Chebyshev polynomial at the normalized time point
      #
      # Uses the Clenshaw algorithm for numerical stability. The algorithm
      # evaluates the polynomial using a recurrence relation, which is more
      # stable than direct power series evaluation.
      #
      # @return [Numo::DFloat] Evaluation result, array of size dimension
      #   (usually 3)
      def evaluate
        @polynomials ||= generate_polynomials(@degree, @dimension)
        combine_polynomials(@polynomials)
      end

      # Calculates the derivative of the Chebyshev polynomial
      #
      # For astronomical calculations, this typically represents velocity.
      # For polynomials of degree < 2, returns zero array since the derivative
      # of constants and linear terms are constant or zero.
      #
      # If radius is provided, scales the result to convert from normalized time
      # units to physical units (usually km/sec in astronomical calculations)
      #
      # @return [Numo::DFloat] Derivative values, array of size dimension
      #   (usually 3)
      def evaluate_derivative
        return Numo::DFloat.zeros(@dimension) if @degree < 2

        derivative = calculate_derivative(@degree, @dimension)
        scale_derivative(derivative)
      end

      private

      def validate_inputs(coefficients, normalized_time)
        unless coefficients.is_a?(Numo::NArray) && coefficients.ndim == 2
          raise InvalidInputError, "Coefficients must be a 2D Numo::NArray"
        end

        unless (-1.0..1.0).cover?(normalized_time)
          raise InvalidInputError, "Normalized time must be in range [-1, 1]"
        end
      end

      # Generates the sequence of Chebyshev polynomials
      # Uses the recurrence relation for Chebyshev polynomials:
      # T₀(x) = 1
      # T₁(x) = x
      # Tₙ₊₁(x) = 2xTₙ(x) - Tₙ₋₁(x)
      def generate_polynomials(degree, dimension)
        polynomials = initialize_base_polynomials(dimension)
        return polynomials if degree <= 2

        build_polynomial_sequence(polynomials, degree)
        polynomials
      end

      # Initializes T₀(x) = 1 and T₁(x) = x polynomials
      def initialize_base_polynomials(dimension)
        [
          Numo::DFloat.ones(dimension),
          @normalized_time * Numo::DFloat.ones(dimension)
        ]
      end

      def build_polynomial_sequence(polynomials, degree)
        (2...degree).each do |i|
          polynomials << compute_next_polynomial(
            polynomials[i - 2],
            polynomials[i - 1]
          )
        end
      end

      def compute_next_polynomial(prev_prev, prev)
        @two_times_normalized_time * prev - prev_prev
      end

      # Combines polynomials with their coefficients
      # Uses vectorized operations for efficiency. The final result is:
      # Σ(coefficients[i] * polynomials[i]) for i from 0 to degree-1
      def combine_polynomials(polynomials)
        (0...@degree).inject(Numo::DFloat.zeros(@dimension)) do |result, i|
          result + @coefficients[i, true] * polynomials[i]
        end
      end

      # Calculates derivative using the modified Clenshaw algorithm
      # The algorithm is adapted to compute derivatives of Chebyshev polynomials
      # while maintaining numerical stability
      def calculate_derivative(degree, dimension)
        @polynomials ||= generate_polynomials(degree, dimension)

        derivative_prev = Numo::DFloat.zeros(dimension)
        derivative = derivative_prev.clone

        (degree - 1).downto(1) do |i|
          derivative_next = derivative.clone
          derivative = derivative_prev
          derivative_prev = calculate_derivative_term(
            i,
            derivative,
            derivative_next
          )
        end

        derivative_prev
      end

      def calculate_derivative_term(index, deriv, deriv_next)
        @two_times_normalized_time * deriv -
          deriv_next +
          @coefficients[index, true] * 2 * index
      end

      def scale_derivative(derivative)
        return derivative unless @radius

        derivative * (SECONDS_PER_DAY / (2.0 * @radius))
      end
    end
  end
end
