# frozen_string_literal: true

module Ephem
  module Core
    class State
      attr_reader :position, :velocity

      def initialize(position, velocity)
        @position = position
        @velocity = velocity
      end

      def self.from_arrays(pos_arr, vel_arr)
        new(
          Vector.new(pos_arr[0], pos_arr[1], pos_arr[2]),
          Vector.new(vel_arr[0], vel_arr[1], vel_arr[2])
        )
      end

      def to_arrays
        [position.to_a, velocity.to_a]
      end
    end
  end
end
