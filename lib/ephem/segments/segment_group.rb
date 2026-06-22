# frozen_string_literal: true

module Ephem
  module Segments
    # Several segments that share the same key (an SPK center/target pair, or a
    # PCK body) but cover different, contiguous time intervals. Each query is
    # routed to the segment covering the requested time, so a body that a kernel
    # splits across several intervals behaves as a single, continuous source.
    #
    # SPK and PCK only build a group when a key actually has more than one
    # segment; the common single-segment case returns the bare segment, so this
    # routing never sits in the hot path for it.
    #
    # Subclasses ({PositionGroup}, {OrientationGroup}) add the query methods
    # appropriate to the segments they hold.
    class SegmentGroup
      # Wraps segments that share a key. A single segment is returned as-is, so
      # the common case carries no routing overhead; only a key spanning several
      # time intervals becomes a group.
      #
      # @param segments [Array<BaseSegment>] segments sharing the same key
      # @return [BaseSegment, SegmentGroup]
      def self.wrap(segments)
        segments.one? ? segments.first : new(segments)
      end

      # @return [Array<BaseSegment>] the underlying segments
      attr_reader :segments

      # @param segments [Array<BaseSegment>] segments sharing the same key
      def initialize(segments)
        @segments = segments
      end

      # Clears cached data for every segment in the group.
      #
      # @return [void]
      def clear_data
        @segments.each(&:clear_data)
      end

      def to_s
        @segments.join("\n")
      end

      private

      # Routes a query to the covering segment(s) and assembles the result. For
      # a scalar time the block is called once with that segment and time; for
      # an array, times are grouped by covering segment so each is queried in a
      # single batched call, then results are reassembled in input order.
      def query(tdb, tdb2)
        if tdb.is_a?(Array)
          query_many(tdb, tdb2) { |segment, times| yield segment, times, tdb2 }
        else
          yield segment_for(tdb, tdb2), tdb, tdb2
        end
      end

      def query_many(times, tdb2)
        results = Array.new(times.size)
        indices_by_segment = times.each_index.group_by do |index|
          segment_for(times[index], tdb2)
        end

        indices_by_segment.each do |segment, indices|
          segment_results = yield(segment, indices.map { |index| times[index] })
          indices.each_with_index do |original_index, position|
            results[original_index] = segment_results[position]
          end
        end

        results
      end

      def segment_for(tdb, tdb2)
        @segments.find { |segment| segment.covers?(tdb, tdb2) } ||
          raise(OutOfRangeError.new(
            "Time #{tdb} is outside the coverage of this group", tdb
          ))
      end
    end
  end
end
