# frozen_string_literal: true

module Ephem
  module Core
    # The orientation of a body, expressed as the three Euler angles that rotate
    # a reference frame (e.g. J2000/ICRF) into the body-fixed frame, optionally
    # with their time derivatives.
    #
    # For binary PCK orientation kernels the angles are the classical 3-1-3
    # (Z-X-Z) sequence: +phi+ and +theta+ orient the pole and +psi+ is the
    # rotation about it (the prime meridian). Angles are in radians and rates,
    # when present, in radians per day — matching ephem's per-day rate
    # convention for SPK velocities (divide by 86400 for radians per second).
    class Orientation
      # @return [Numeric] first Euler angle (radians)
      attr_reader :phi

      # @return [Numeric] second Euler angle (radians)
      attr_reader :theta

      # @return [Numeric] third Euler angle (radians)
      attr_reader :psi

      # @return [Array<Numeric>, nil] [phi, theta, psi] rates (radians/day),
      #   or nil when the orientation carries no rates
      attr_reader :rates

      # @param phi [Numeric] first Euler angle (radians)
      # @param theta [Numeric] second Euler angle (radians)
      # @param psi [Numeric] third Euler angle (radians)
      # @param rates [Array<Numeric>, nil] optional [phi, theta, psi] rates
      #   (radians/day)
      # @raise [Ephem::InvalidInputError] if any angle or rate is not numeric
      def initialize(phi, theta, psi, rates: nil)
        unless phi.is_a?(Numeric) && theta.is_a?(Numeric) && psi.is_a?(Numeric)
          raise InvalidInputError, "Orientation angles must be numeric"
        end

        unless rates.nil? || valid_rates?(rates)
          raise InvalidInputError, "Orientation rates must be three numerics"
        end

        @phi = phi
        @theta = theta
        @psi = psi
        @rates = rates&.freeze
        freeze
      end

      def self.[](phi, theta, psi, rates: nil)
        new(phi, theta, psi, rates: rates)
      end

      # @return [Boolean] whether this orientation carries rates
      def rates?
        !@rates.nil?
      end

      # @return [Array<Numeric>] the three Euler angles [phi, theta, psi]
      def to_a
        [phi, theta, psi]
      end

      # The rotation matrix that maps the reference frame into the body-fixed
      # frame, built from the 3-1-3 (Z-X-Z) Euler angles:
      # +M = Rz(psi) * Rx(theta) * Rz(phi)+. Rates are ignored.
      #
      # @return [Array<Array<Float>>] a 3x3 rotation matrix
      def to_matrix
        Rotation.multiply(
          Rotation.about_z(psi),
          Rotation.about_x(theta),
          Rotation.about_z(phi)
        )
      end

      # @param index [Integer] 0 for phi, 1 for theta, 2 for psi
      # @return [Numeric] the angle at the given index
      # @raise [Ephem::IndexError] if index is not 0, 1, or 2
      def [](index)
        case index
        when 0 then phi
        when 1 then theta
        when 2 then psi
        else raise IndexError, "Invalid index: #{index}"
        end
      end

      def inspect
        body = "phi: #{phi}, theta: #{theta}, psi: #{psi}"
        body += ", rates: #{rates}" if rates?
        "Orientation[#{body}]"
      end
      alias_method :to_s, :inspect

      def hash
        [phi, theta, psi, rates, self.class].hash
      end

      def ==(other)
        unless other.is_a?(self.class)
          raise InvalidInputError, "Can only compare with another Orientation"
        end

        to_a == other.to_a && rates == other.rates
      end
      alias_method :eql?, :==

      private

      def valid_rates?(rates)
        rates.is_a?(Array) &&
          rates.size == 3 &&
          rates.all?(Numeric)
      end
    end
  end
end
