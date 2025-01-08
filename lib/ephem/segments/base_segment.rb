# frozen_string_literal: true

module Ephem
  module Segments
    class BaseSegment
      include Core::Constants
      include Core::CalendarCalculations

      TARGET_NAMES = {
        Bodies::SOLAR_SYSTEM_BARYCENTER => "Solar System Barycenter",
        Bodies::MERCURY_BARYCENTER => "Mercury Barycenter",
        Bodies::VENUS_BARYCENTER => "Venus Barycenter",
        Bodies::EARTH_MOON_BARYCENTER => "Earth-Moon Barycenter",
        Bodies::MARS_BARYCENTER => "Mars Barycenter",
        Bodies::JUPITER_BARYCENTER => "Jupiter Barycenter",
        Bodies::SATURN_BARYCENTER => "Saturn Barycenter",
        Bodies::URANUS_BARYCENTER => "Uranus Barycenter",
        Bodies::NEPTUNE_BARYCENTER => "Neptune Barycenter",
        Bodies::PLUTO_BARYCENTER => "Pluto Barycenter",
        Bodies::SUN => "Sun",
        Bodies::MERCURY => "Mercury",
        Bodies::VENUS => "Venus",
        Bodies::MOON => "Moon",
        Bodies::EARTH => "Earth",
        Bodies::MARS => "Mars",
        Bodies::JUPITER => "Jupiter",
        Bodies::SATURN => "Saturn",
        Bodies::URANUS => "Uranus",
        Bodies::NEPTUNE => "Neptune",
        Bodies::PLUTO => "Pluto"
      }.freeze

      # @return [Ephem::IO::DAF] the DAF object representing the data file
      attr_reader :daf
      # @return [Integer] the target body ID
      attr_reader :target
      # @return [Integer] the center body ID
      attr_reader :center

      # Initialize a new segment
      #
      # @param daf [Ephem::IO::DAF] the DAF object representing the data file
      # @param source [String] the source identifier of the segment
      # @param descriptor [Array] array containing segment descriptors:
      #   * start_second [Float] start time in seconds from J2000
      #   * end_second [Float] end time in seconds from J2000
      #   * target [Integer] target body ID
      #   * center [Integer] center body ID
      #   * frame [String] reference frame identifier
      #   * data_type [Integer] type of data in the segment
      #   * start_i [Integer] start index in the data array
      #   * end_i [Integer] end index in the data array
      def initialize(daf:, source:, descriptor:)
        @daf = daf
        @source = source
        @start_second,
          @end_second,
          @target,
          @center,
          @frame,
          @data_type,
          @start_i,
          @end_i = descriptor
        @start_jd = compute_julian_date(@start_second)
        @end_jd = compute_julian_date(@end_second)
      end

      # String representation of the segment
      #
      # @return [String] segment description in non-verbose format
      def to_s
        describe(verbose: false)
      end

      # Detailed description of the segment
      #
      # @param verbose [Boolean] whether to include additional details
      # @return [String] formatted description of the segment
      def describe(verbose: false)
        start_date = format_date(*julian_to_gregorian(@start_jd))
        end_date = format_date(*julian_to_gregorian(@end_jd))

        center_name = get_body_name(@center, "Unknown Center")
        target_name = get_body_name(@target, "Unknown Target")

        dates = "#{start_date}..#{end_date}"
        center = "#{center_name} (#{@center})"
        target = "#{target_name} (#{@target})"
        description = "#{dates} Type #{@data_type} #{center} -> #{target}"
        return description unless verbose

        <<~DESCRIPTION.chomp
          #{description}
          frame=#{@frame} source=#{@source}
        DESCRIPTION
      end

      def compute(_tdb, _tdb2 = 0.0)
        raise NotImplementedError,
          "#{self.class} has not implemented compute() for data type #{@data_type}"
      end

      def compute_and_differentiate(_tdb, _tdb2 = 0.0)
        raise NotImplementedError,
          "#{self.class} has not implemented compute_and_differentiate() for data type #{@data_type}"
      end

      def clear_data
        # Placeholder method to clear any cached data
      end

      private

      def compute_julian_date(seconds)
        Time::J2000_EPOCH + seconds / Time::SECONDS_PER_DAY
      end

      def get_body_name(id, default)
        name = TARGET_NAMES.fetch(id, default)
        titlecase(name)
      end

      def titlecase(name)
        return name if name.start_with?("1", "C/", "DSS-")

        name.split.then { |words| words.map(&:capitalize).join(" ") }
      end
    end
  end
end
