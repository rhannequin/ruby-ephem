# frozen_string_literal: true

module Ephem
  module Segments
    # Builds the error raised when a query asks for times a segment, or a
    # group of segments, does not cover.
    module Coverage
      extend Core::CalendarCalculations

      # @param times [Array<Numeric>] the uncovered times, as TDB Julian Dates
      # @param label [String] what the segments describe, e.g.
      #   "Solar System Barycenter (0) -> Earth-Moon Barycenter (3)"
      # @param ranges [Array<Array(Float, Float)>] the covered Julian Date
      #   ranges, as [start_jd, end_jd] pairs
      # @return [Ephem::OutOfRangeError]
      def self.out_of_range_error(times:, label:, ranges:)
        message = "#{describe_times(times)} outside the coverage of " \
          "#{label}, which covers #{describe_ranges(ranges)}"
        OutOfRangeError.new(message, times)
      end

      def self.describe_times(times)
        first_time = describe_time(times.first)
        other_count = times.size - 1
        return "#{first_time} is" if other_count.zero?

        noun = (other_count == 1) ? "time" : "times"
        "#{first_time} and #{other_count} other #{noun} are"
      end

      def self.describe_time(julian_date)
        return "JD #{julian_date}" unless julian_date.finite?

        "JD #{julian_date} (#{calendar_date(julian_date)})"
      end

      def self.describe_ranges(ranges)
        merge(ranges).map do |start_jd, end_jd|
          "JD #{start_jd}..#{end_jd} " \
            "(#{calendar_date(start_jd)}..#{calendar_date(end_jd)})"
        end.join(", ")
      end

      def self.merge(ranges)
        ranges.sort.each_with_object([]) do |(start_jd, end_jd), merged|
          last_range = merged.last
          if last_range && start_jd <= last_range[1]
            last_range[1] = [last_range[1], end_jd].max
          else
            merged << [start_jd, end_jd]
          end
        end
      end

      def self.calendar_date(julian_date)
        format_date(*julian_to_gregorian(julian_date))
      end

      private_class_method :describe_times,
        :describe_time,
        :describe_ranges,
        :merge,
        :calendar_date
    end
  end
end
