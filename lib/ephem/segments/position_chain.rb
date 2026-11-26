# frozen_string_literal: true

module Ephem
  module Segments
    # Position of a target relative to a center that no single SPK pair
    # stores, built by adding and subtracting the stored pairs along the path
    # between the two bodies. Earth relative to the Solar System Barycenter,
    # for instance, is (0 -> 3) + (3 -> 399), and the Moon relative to the
    # Earth is (3 -> 301) - (3 -> 399). Built by SPK#position_at and
    # SPK#state_at.
    class PositionChain
      Link = Struct.new(:source, :forward)

      ZERO_VECTOR = Core::Vector.new(0.0, 0.0, 0.0)
      ZERO_STATE = Core::State.new(ZERO_VECTOR, ZERO_VECTOR)

      # @return [Array<Link>] the stored pairs on the path
      attr_reader :links

      # @param links [Array<Link>] the stored pairs on the path, in any order
      def initialize(links)
        forward_links, backward_links = links.partition(&:forward)
        @links = (forward_links + backward_links).freeze
        @sources = @links.map(&:source).freeze
        @signs = @links.map { |link| link.forward ? 1.0 : -1.0 }.freeze
      end

      # Position of the target relative to the center.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::Vector, Array<Core::Vector>] Position(s) in km
      # @raise [Ephem::OutOfRangeError] if a pair on the path does not cover
      #   the time
      def compute(tdb, tdb2 = 0.0)
        return compute_many(tdb, tdb2) if tdb.is_a?(Array)
        return ZERO_VECTOR if @sources.empty?

        total_x = total_y = total_z = 0.0
        link_index = 0
        while link_index < @sources.size
          position = @sources[link_index].position_components(tdb, tdb2)
          sign = @signs[link_index]
          total_x += sign * position[0]
          total_y += sign * position[1]
          total_z += sign * position[2]
          link_index += 1
        end
        Core::Vector.new(total_x, total_y, total_z)
      end

      # Position and velocity of the target relative to the center.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::State, Array<Core::State>] State(s) in km and km/day
      # @raise [Ephem::OutOfRangeError] if a pair on the path does not cover
      #   the time
      def compute_and_differentiate(tdb, tdb2 = 0.0)
        if tdb.is_a?(Array)
          return compute_and_differentiate_many(tdb, tdb2)
        end
        return ZERO_STATE if @sources.empty?

        position_x = position_y = position_z = 0.0
        velocity_x = velocity_y = velocity_z = 0.0
        link_index = 0
        while link_index < @sources.size
          position, velocity =
            @sources[link_index].state_components(tdb, tdb2)
          sign = @signs[link_index]
          position_x += sign * position[0]
          position_y += sign * position[1]
          position_z += sign * position[2]
          velocity_x += sign * velocity[0]
          velocity_y += sign * velocity[1]
          velocity_z += sign * velocity[2]
          link_index += 1
        end
        Core::State.new(
          Core::Vector.new(position_x, position_y, position_z),
          Core::Vector.new(velocity_x, velocity_y, velocity_z)
        )
      end

      private

      def compute_many(times, tdb2)
        return Array.new(times.size, ZERO_VECTOR) if @sources.empty?

        terms = @sources.map { |source| source.compute(times, tdb2) }
        Array.new(times.size) do |time_index|
          signed_sum(terms.map { |positions| positions[time_index] })
        end
      end

      def compute_and_differentiate_many(times, tdb2)
        return Array.new(times.size, ZERO_STATE) if @sources.empty?

        terms = @sources.map do |source|
          source.compute_and_differentiate(times, tdb2)
        end
        Array.new(times.size) do |time_index|
          states = terms.map { |source_states| source_states[time_index] }
          Core::State.new(
            signed_sum(states.map(&:position)),
            signed_sum(states.map(&:velocity))
          )
        end
      end

      def signed_sum(vectors)
        total_x = total_y = total_z = 0.0
        vectors.each_with_index do |vector, link_index|
          sign = @signs[link_index]
          total_x += sign * vector.x
          total_y += sign * vector.y
          total_z += sign * vector.z
        end
        Core::Vector.new(total_x, total_y, total_z)
      end
    end
  end
end
