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
      ZERO_STATE = Core::State.new(ZERO_VECTOR, ZERO_VECTOR).freeze

      # @return [Array<Link>] the stored pairs on the path
      attr_reader :links

      # @param links [Array<Link>] the stored pairs on the path, in any order
      def initialize(links)
        forward_links, backward_links = links.partition(&:forward)
        @links = (forward_links + backward_links).freeze
      end

      # Position of the target relative to the center.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::Vector, Array<Core::Vector>] Position(s) in km
      # @raise [Ephem::OutOfRangeError] if a pair on the path does not cover
      #   the time
      def compute(tdb, tdb2 = 0.0)
        combine(tdb, ZERO_VECTOR) { |source| source.compute(tdb, tdb2) }
      end

      # Position and velocity of the target relative to the center.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::State, Array<Core::State>] State(s) in km and km/day
      # @raise [Ephem::OutOfRangeError] if a pair on the path does not cover
      #   the time
      def compute_and_differentiate(tdb, tdb2 = 0.0)
        combine(tdb, ZERO_STATE) do |source|
          source.compute_and_differentiate(tdb, tdb2)
        end
      end

      private

      def combine(tdb, zero)
        if @links.empty?
          return tdb.is_a?(Array) ? Array.new(tdb.size, zero) : zero
        end

        terms = @links.map { |link| yield(link.source) }
        unless tdb.is_a?(Array)
          return signed_sum { |link_index| terms[link_index] }
        end

        Array.new(tdb.size) do |time_index|
          signed_sum { |link_index| terms[link_index][time_index] }
        end
      end

      def signed_sum
        first_term = yield(0)
        total = @links.first.forward ? first_term : negate(first_term)
        (1...@links.size).each do |link_index|
          term = yield(link_index)
          total = if @links[link_index].forward
            add(total, term)
          else
            subtract(total, term)
          end
        end
        total
      end

      def add(total, term)
        return total + term unless total.is_a?(Core::State)

        Core::State.new(
          total.position + term.position,
          total.velocity + term.velocity
        )
      end

      def subtract(total, term)
        return total - term unless total.is_a?(Core::State)

        Core::State.new(
          total.position - term.position,
          total.velocity - term.velocity
        )
      end

      def negate(term)
        subtract(term.is_a?(Core::State) ? ZERO_STATE : ZERO_VECTOR, term)
      end
    end
  end
end
