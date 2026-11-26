# frozen_string_literal: true

module Ephem
  module Core
    # Represents the state of a celestial object in space, consisting of its
    # position and velocity vectors. This class is fundamental for describing
    # orbital motion and performing astronomical calculations.
    #
    # @example Create a state for a celestial object
    #   position = Ephem::Core::Vector.new(1.0, 2.0, 3.0)
    #   velocity = Ephem::Core::Vector.new(0.1, 0.2, 0.3)
    #   state = Ephem::Core::State.new(position, velocity)
    class State
      # @return [Ephem::Core::Vector] The position vector of the object
      attr_reader :position

      # @return [Ephem::Core::Vector] The velocity vector of the object
      attr_reader :velocity

      # Creates a new State instance.
      #
      # @param position [Ephem::Core::Vector] The position vector
      # @param velocity [Ephem::Core::Vector] The velocity vector
      #
      # @example A state at the solar system barycenter with zero velocity
      #   position = Ephem::Core::Vector.new(0.0, 0.0, 0.0)
      #   velocity = Ephem::Core::Vector.new(0.0, 0.0, 0.0)
      #   state = Ephem::Core::State.new(position, velocity)
      def initialize(position, velocity)
        @position = position
        @velocity = velocity
        freeze
      end

      # Creates a State instance from arrays of position and velocity
      # components.
      #
      # @param position [Array<Numeric>] Array of [x, y, z] position components
      # @param velocity [Array<Numeric>] Array of [vx, vy, vz] velocity
      #   components
      #
      # @return [Ephem::Core::State] A new State instance
      #
      # @example Create a state from arrays
      #   position = [1.0, 2.0, 3.0]
      #   velocity = [0.1, 0.2, 0.3]
      #   state = Ephem::Core::State.from_arrays(position, velocity)
      def self.from_arrays(position, velocity)
        new(
          Vector.new(position[0], position[1], position[2]),
          Vector.new(velocity[0], velocity[1], velocity[2])
        )
      end

      def inspect
        "State[position: #{position}, velocity: #{velocity}]"
      end
      alias_method :to_s, :inspect

      # Converts the state vectors to arrays.
      #
      # @return [Array<Array<Numeric>>] Array containing position and velocity
      #   arrays
      #
      # @example Get position and velocity components as arrays
      #   pos_arr, vel_arr = state.to_arrays
      def to_arrays
        [position.to_a, velocity.to_a]
      end

      # Generates a hash value for the state.
      #
      # @return [Integer] Hash value based on position, velocity and class
      def hash
        [position, velocity, self.class].hash
      end

      # Checks equality with another state.
      #
      # @param other [Object] The object to compare with
      #
      # @return [Boolean] true if other is a State with equal position and
      #   velocity vectors, false otherwise
      #
      # @example Check if two states are equal
      #   state1 == state2
      def ==(other)
        other.instance_of?(self.class) &&
          position == other.position &&
          velocity == other.velocity
      end

      # Checks strict equality with another state, as used by Hash keys.
      #
      # @param other [Object] The object to compare with
      #
      # @return [Boolean] true if other is a State whose position and velocity
      #   vectors are eql?, false otherwise
      def eql?(other)
        other.instance_of?(self.class) &&
          position.eql?(other.position) &&
          velocity.eql?(other.velocity)
      end
    end
  end
end
