# frozen_string_literal: true

module Ephem
  module Core
    # Represents the state of a celestial object in space, consisting of its
    # position and velocity vectors. This class is fundamental for describing
    # orbital motion and performing astronomical calculations.
    #
    # @example Create a state for a celestial object
    #   position = Ephem::Vector.new(1.0, 2.0, 3.0)
    #   velocity = Ephem::Vector.new(0.1, 0.2, 0.3)
    #   state = Ephem::State.new(position, velocity)
    class State
      # @return [Ephem::Vector] The position vector of the object
      attr_reader :position

      # @return [Ephem::Vector] The velocity vector of the object
      attr_reader :velocity

      # Creates a new State instance.
      #
      # @param position [Ephem::Vector] The position vector
      # @param velocity [Ephem::Vector] The velocity vector
      #
      # @example Create a state at the solar system barycenter with zero velocity
      #   position = Ephem::Vector.new(0.0, 0.0, 0.0)
      #   velocity = Ephem::Vector.new(0.0, 0.0, 0.0)
      #   state = Ephem::State.new(position, velocity)
      def initialize(position, velocity)
        @position = position
        @velocity = velocity
      end

      # Creates a State instance from arrays of position and velocity
      # components.
      #
      # @param position [Array<Numeric>] Array of [x, y, z] position components
      # @param velocity [Array<Numeric>] Array of [vx, vy, vz] velocity
      #   components
      #
      # @return [Ephem::State] A new State instance
      #
      # @example Create a state from arrays
      #   position = [1.0, 2.0, 3.0]
      #   velocity = [0.1, 0.2, 0.3]
      #   state = Ephem::State.from_arrays(position, velocity)
      def self.from_arrays(position, velocity)
        new(
          Vector.new(position[0], position[1], position[2]),
          Vector.new(velocity[0], velocity[1], velocity[2])
        )
      end

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
    end
  end
end
