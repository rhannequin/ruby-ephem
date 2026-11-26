# frozen_string_literal: true

module Ephem
  module Segments
    # The position segments for one SPK center/target pair. Routes each query to
    # the segment covering the requested time. Returned by SPK#[].
    #
    # @see Ephem::Segments::Segment
    class PositionGroup < SegmentGroup
      # @return [Integer] the center body ID
      def center
        @segments.first.center
      end

      # @return [Integer] the target body ID
      def target
        @segments.first.target
      end

      # Position at the given time. See {Segment#compute}.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::Vector, Array<Core::Vector>]
      def compute(tdb, tdb2 = 0.0)
        query(tdb, tdb2) do |segment, time, fraction|
          segment.compute(time, fraction)
        end
      end
      alias_method :position_at, :compute

      # Position and velocity at the given time. See
      # {Segment#compute_and_differentiate}.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::State, Array<Core::State>]
      def compute_and_differentiate(tdb, tdb2 = 0.0)
        query(tdb, tdb2) do |segment, time, fraction|
          segment.compute_and_differentiate(time, fraction)
        end
      end
      alias_method :state_at, :compute_and_differentiate

      # See {Segment#position_components}.
      #
      # @api private
      # @param tdb [Numeric] Time in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Array<Float>]
      def position_components(tdb, tdb2 = 0.0)
        query(tdb, tdb2) do |segment, time, fraction|
          segment.position_components(time, fraction)
        end
      end

      # See {Segment#state_components}.
      #
      # @api private
      # @param tdb [Numeric] Time in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Array(Array<Float>, Array<Float>)]
      def state_components(tdb, tdb2 = 0.0)
        query(tdb, tdb2) do |segment, time, fraction|
          segment.state_components(time, fraction)
        end
      end
    end
  end
end
