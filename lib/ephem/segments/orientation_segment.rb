# frozen_string_literal: true

module Ephem
  module Segments
    # Binary PCK orientation segment (data type 2): the orientation of a body
    # frame relative to an inertial reference frame, stored as three Euler
    # angles in Chebyshev coefficients.
    class OrientationSegment < BaseSegment
      include ChebyshevType2
      include OrientationSource

      COMPONENT_COUNT = 3 # phi, theta, psi

      def initialize(daf:, source:, descriptor:)
        super
        @data_loaded = false
        @data_lock = Mutex.new
      end

      # @return [Integer] NAIF frame ID of the oriented body frame
      alias_method :body, :target
      # @return [Integer] NAIF ID of the inertial reference frame
      alias_method :reference_frame, :center

      # Euler angles at the given time, without rates.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::Orientation, Array<Core::Orientation>] angles in radians
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      def angles_at(tdb, tdb2 = 0.0)
        load_data
        tdb_seconds = convert_to_seconds(tdb, tdb2)

        case tdb_seconds
        when Numeric
          to_orientation(generate_position(tdb_seconds))
        else
          tdb_seconds.map do |seconds|
            to_orientation(generate_position(seconds))
          end
        end
      end

      # Euler angles and their rates at the given time.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Core::Orientation, Array<Core::Orientation>] angles (radians)
      #   carrying rates (radians/day)
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      def orientation_at(tdb, tdb2 = 0.0)
        load_data
        tdb_seconds = convert_to_seconds(tdb, tdb2)

        case tdb_seconds
        when Numeric
          to_orientation(*generate_single(tdb_seconds))
        else
          generate_multiple(tdb_seconds).map do |angles, rates|
            to_orientation(angles, rates)
          end
        end
      end

      # The reference-frame to body-fixed rotation matrix at the given time,
      # built from the 3-1-3 Euler angles. See {Core::Orientation#to_matrix}.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Array<Array<Float>>, Array<Array<Array<Float>>>] a 3x3 matrix,
      #   or one per time for an array input
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      def matrix_at(tdb, tdb2 = 0.0)
        angles = angles_at(tdb, tdb2)
        angles.is_a?(Array) ? angles.map(&:to_matrix) : angles.to_matrix
      end

      def describe(verbose: false)
        start_date = format_date(*julian_to_gregorian(@start_jd))
        end_date = format_date(*julian_to_gregorian(@end_jd))

        description =
          "#{start_date}..#{end_date} Type #{@data_type} orientation of " \
          "frame #{body} relative to frame #{reference_frame}"
        return description unless verbose

        <<~DESCRIPTION.chomp
          #{description}
          source=#{@source}
        DESCRIPTION
      end

      private

      def parse_descriptor(descriptor)
        @start_second,
          @end_second,
          @target,
          @center,
          @data_type,
          @start_i,
          @end_i = descriptor
        @frame = @center
      end

      def component_count
        COMPONENT_COUNT
      end

      def to_orientation(angles, rates = nil)
        Core::Orientation.new(angles[0], angles[1], angles[2], rates: rates)
      end

      Registry.register(:pck, 2, self)
    end
  end
end
