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
    end
  end
end
