# frozen_string_literal: true

module Ephem
  module Computation
    ##
    # High-performance, three-dimensional Clenshaw evaluation and derivative
    # evaluation for Chebyshev polynomials, as used in SPK ephemerides.
    #
    # @see https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/cheby.html
    # @see https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/FORTRAN/spicelib/spkche.html
    #
    module ChebyshevPolynomial
      ##
      # Evaluates a 3D Chebyshev polynomial at a given normalized time.
      #
      # @param coefficients [Array<Array<Float>>] Array of coefficients; shape
      #   is [n_terms][3].
      # @param normalized_time [Float] The normalized independent variable, in
      #   [-1, 1].
      # @return [Array<Float>] The 3-vector result at normalized_time:
      #   [x, y, z]
      def self.evaluate(coefficients, normalized_time)
        sum_x = sum_y = sum_z = 0.0
        previous_sum_x = previous_sum_y = previous_sum_z = 0.0

        twice_time = 2.0 * normalized_time
        degree = coefficients.size - 1
        while degree > 0
          term = coefficients[degree]
          coefficient_x = term[0]
          coefficient_y = term[1]
          coefficient_z = term[2]
          new_sum_x = twice_time * sum_x - previous_sum_x + coefficient_x
          new_sum_y = twice_time * sum_y - previous_sum_y + coefficient_y
          new_sum_z = twice_time * sum_z - previous_sum_z + coefficient_z
          previous_sum_x = sum_x
          previous_sum_y = sum_y
          previous_sum_z = sum_z
          sum_x = new_sum_x
          sum_y = new_sum_y
          sum_z = new_sum_z
          degree -= 1
        end

        coefficient_x, coefficient_y, coefficient_z = coefficients[0]
        [
          normalized_time * sum_x - previous_sum_x + coefficient_x,
          normalized_time * sum_y - previous_sum_y + coefficient_y,
          normalized_time * sum_z - previous_sum_z + coefficient_z
        ]
      end

      ##
      # Evaluates a 3D Chebyshev polynomial and its time derivative in a single
      # pass, sharing the coefficient fetch and loop control. The position is
      # bit-for-bit identical to {evaluate}.
      #
      # @param coefficients [Array<Array<Float>>] coefficients; shape
      #   [n_terms][3].
      # @param normalized_time [Float] normalized independent variable, in
      #   [-1, 1].
      # @param radius [Float] half-length of the time interval (seconds).
      # @return [Array(Array<Float>, Array<Float>)] [position, velocity], with
      #   velocity in units per day.
      def self.evaluate_with_derivative(coefficients, normalized_time, radius)
        sum_x = sum_y = sum_z = 0.0
        previous_sum_x = previous_sum_y = previous_sum_z = 0.0
        derivative_x = derivative_y = derivative_z = 0.0
        previous_derivative_x = previous_derivative_y =
          previous_derivative_z = 0.0

        twice_time = 2.0 * normalized_time
        degree = coefficients.size - 1
        while degree > 0
          term = coefficients[degree]
          coefficient_x = term[0]
          coefficient_y = term[1]
          coefficient_z = term[2]
          twice_degree = 2 * degree

          new_sum_x = twice_time * sum_x - previous_sum_x + coefficient_x
          new_sum_y = twice_time * sum_y - previous_sum_y + coefficient_y
          new_sum_z = twice_time * sum_z - previous_sum_z + coefficient_z
          new_derivative_x = twice_time * derivative_x -
            previous_derivative_x + twice_degree * coefficient_x
          new_derivative_y = twice_time * derivative_y -
            previous_derivative_y + twice_degree * coefficient_y
          new_derivative_z = twice_time * derivative_z -
            previous_derivative_z + twice_degree * coefficient_z

          previous_sum_x = sum_x
          previous_sum_y = sum_y
          previous_sum_z = sum_z
          sum_x = new_sum_x
          sum_y = new_sum_y
          sum_z = new_sum_z
          previous_derivative_x = derivative_x
          previous_derivative_y = derivative_y
          previous_derivative_z = derivative_z
          derivative_x = new_derivative_x
          derivative_y = new_derivative_y
          derivative_z = new_derivative_z
          degree -= 1
        end

        coefficient_x, coefficient_y, coefficient_z = coefficients[0]
        position = [
          normalized_time * sum_x - previous_sum_x + coefficient_x,
          normalized_time * sum_y - previous_sum_y + coefficient_y,
          normalized_time * sum_z - previous_sum_z + coefficient_z
        ]

        scale = Ephem::Core::Constants::Time::SECONDS_PER_DAY / (2.0 * radius)
        velocity = [derivative_x * scale, derivative_y * scale,
          derivative_z * scale]

        [position, velocity]
      end
    end
  end
end
