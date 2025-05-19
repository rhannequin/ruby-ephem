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
      # @param coeffs [Array<Array<Float>>] Array of coefficients; shape is
      #   [n_terms][3].
      # @param t [Float] The normalized independent variable, in [-1, 1].
      # @return [Array<Float>] The 3-vector result at t: [x, y, z]
      def self.evaluate(coeffs, t)
        n = coeffs.size
        b1x = b1y = b1z = 0.0
        b2x = b2y = b2z = 0.0

        k = n - 1
        while k > 0
          c = coeffs[k]
          c0 = c[0]
          c1 = c[1]
          c2 = c[2]
          t2 = 2.0 * t
          tx = t2 * b1x - b2x + c0
          ty = t2 * b1y - b2y + c1
          tz = t2 * b1z - b2z + c2
          b2x = b1x
          b2y = b1y
          b2z = b1z
          b1x = tx
          b1y = ty
          b1z = tz
          k -= 1
        end

        c0, c1, c2 = coeffs[0]
        [t * b1x - b2x + c0, t * b1y - b2y + c1, t * b1z - b2z + c2]
      end

      ##
      # Evaluates the time derivative of a 3D Chebyshev polynomial at a given
      # normalized time.
      #
      # @param coeffs [Array<Array<Float>>] Array of coefficients; shape is
      #   [n_terms][3].
      # @param t [Float] The normalized independent variable (in [-1, 1]).
      # @param radius [Float] The half-length of the time interval (days).
      # @return [Array<Float>] The 3-vector derivative (velocity), in units per
      #   second.
      def self.evaluate_derivative(coeffs, t, radius)
        n = coeffs.size
        return [0.0, 0.0, 0.0] if n < 2

        d1x = d1y = d1z = 0.0
        d2x = d2y = d2z = 0.0

        k = n - 1
        while k > 0
          c = coeffs[k]
          c0 = c[0]
          c1 = c[1]
          c2 = c[2]
          t2 = 2.0 * t
          k2 = 2 * k
          tx = t2 * d1x - d2x + k2 * c0
          ty = t2 * d1y - d2y + k2 * c1
          tz = t2 * d1z - d2z + k2 * c2
          d2x = d1x
          d2y = d1y
          d2z = d1z
          d1x = tx
          d1y = ty
          d1z = tz
          k -= 1
        end

        scale = Ephem::Core::Constants::Time::SECONDS_PER_DAY / (2.0 * radius)
        [d1x * scale, d1y * scale, d1z * scale]
      end
    end
  end
end
