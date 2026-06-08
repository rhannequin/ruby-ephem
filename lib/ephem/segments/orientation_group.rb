# frozen_string_literal: true

module Ephem
  module Segments
    # The orientation segments for one PCK body frame. Routes each query to the
    # segment covering the requested time. Returned by PCK#[].
    #
    # @see Ephem::Segments::OrientationSegment
    class OrientationGroup < SegmentGroup
      # @return [Integer] NAIF frame ID of the oriented body frame
      def body
        @segments.first.body
      end

      # @return [Integer] NAIF ID of the inertial reference frame
      def reference_frame
        @segments.first.reference_frame
      end

      # Euler angles at the given time, without rates. See
      # {OrientationSegment#angles_at}.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::Orientation, Array<Core::Orientation>]
      def angles_at(tdb, tdb2 = 0.0)
        query(tdb, tdb2) do |segment, time, fraction|
          segment.angles_at(time, fraction)
        end
      end

      # Euler angles and their rates at the given time. See
      # {OrientationSegment#orientation_at}.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::Orientation, Array<Core::Orientation>]
      def orientation_at(tdb, tdb2 = 0.0)
        query(tdb, tdb2) do |segment, time, fraction|
          segment.orientation_at(time, fraction)
        end
      end
    end
  end
end
