# frozen_string_literal: true

module Ephem
  module Segments
    # SPK trajectory segment: position (type 2) and position/velocity (type 3)
    # of a target body relative to a center body, stored as Chebyshev
    # coefficients.
    #
    # @example Computing position at a specific time
    #   segment = Ephem::Segments::Segment.new(
    #     daf: daf_object,
    #     source: "DE440.bsp",
    #     descriptor: [...]
    #   )
    #   position = segment.compute(time)  # returns Vector
    #
    # @example Computing position and velocity
    #   state = segment.compute_and_differentiate(time)  # returns State
    #
    # @see Ephem::Core::Vector
    # @see Ephem::Core::State
    # @see Ephem::Segments::ChebyshevType2
    class Segment < BaseSegment
      include ChebyshevType2

      COMPONENT_COUNTS = {
        2 => 3,  # Type 2: position (x, y, z)
        3 => 6   # Type 3: position (x, y, z) and velocity (vx, vy, vz)
      }.freeze

      # Computes the position of the target body relative to the center body at
      # the specified time.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Ephem::Core::Vector] Position vector in kilometers
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      def compute(tdb, tdb2 = 0.0)
        records = load_data
        tdb_seconds = convert_to_seconds(tdb, tdb2)

        case tdb_seconds
        when Numeric
          position = generate_position(records, tdb_seconds)
          Core::Vector.new(position[0], position[1], position[2])
        else
          tdb_seconds.map do |time|
            position = generate_position(records, time)
            Core::Vector.new(position[0], position[1], position[2])
          end
        end
      rescue OutOfRangeError => error
        raise request_out_of_range_error(records, error, tdb, tdb2), cause: nil
      end
      alias_method :position_at, :compute

      # Computes both position and velocity vectors at the specified time.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Ephem::Core::State, Array<Ephem::Core::State>] State object(s)
      #   containing position (km) and velocity (km/day) vectors. Returns an
      #   array if the input is an array.
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      def compute_and_differentiate(tdb, tdb2 = 0.0)
        records = load_data
        tdb_seconds = convert_to_seconds(tdb, tdb2)

        case tdb_seconds
        when Numeric
          position, velocity = generate_single(records, tdb_seconds)
          Core::State.new(
            Core::Vector.new(position[0], position[1], position[2]),
            Core::Vector.new(velocity[0], velocity[1], velocity[2])
          )
        else
          generate_multiple(records, tdb_seconds).map do |position, velocity|
            Core::State.new(
              Core::Vector.new(position[0], position[1], position[2]),
              Core::Vector.new(velocity[0], velocity[1], velocity[2])
            )
          end
        end
      rescue OutOfRangeError => error
        raise request_out_of_range_error(records, error, tdb, tdb2), cause: nil
      end
      alias_method :state_at, :compute_and_differentiate

      # Position at a single time as an [x, y, z] Array, without building a
      # Vector. Used by {PositionChain} to sum the pairs on a path.
      #
      # @api private
      # @param tdb [Numeric] Time in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Array<Float>] Position in km
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      def position_components(tdb, tdb2 = 0.0)
        records = load_data
        generate_position(records, time_to_seconds(tdb, tdb2))
      rescue OutOfRangeError => error
        raise request_out_of_range_error(records, error, tdb, tdb2), cause: nil
      end

      # Position and velocity at a single time as two [x, y, z] Arrays,
      # without building a State. Used by {PositionChain} to sum the pairs on
      # a path.
      #
      # @api private
      # @param tdb [Numeric] Time in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Array(Array<Float>, Array<Float>)] Position in km and
      #   velocity in km/day
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      def state_components(tdb, tdb2 = 0.0)
        records = load_data
        generate_single(records, time_to_seconds(tdb, tdb2))
      rescue OutOfRangeError => error
        raise request_out_of_range_error(records, error, tdb, tdb2), cause: nil
      end

      private

      def process_coefficient_data(data)
        records = super
        return records unless @data_type == 3

        velocity_coefficients = records.coefficients.map do |terms|
          terms.map do |term|
            [
              term[3] * Time::SECONDS_PER_DAY,
              term[4] * Time::SECONDS_PER_DAY,
              term[5] * Time::SECONDS_PER_DAY
            ]
          end
        end
        position_coefficients = records.coefficients.map do |terms|
          terms.map { |term| term.first(3) }
        end

        Records.new(
          midpoints: records.midpoints,
          radii: records.radii,
          coefficients: position_coefficients.freeze,
          velocity_coefficients: velocity_coefficients.freeze
        ).freeze
      end

      def generate_single(records, tdb_seconds)
        return super unless @data_type == 3

        interval = find_interval(records, tdb_seconds)
        normalized_time =
          compute_normalized_time(records, tdb_seconds, interval)
        [
          Computation::ChebyshevPolynomial
            .evaluate(records.coefficients[interval], normalized_time),
          Computation::ChebyshevPolynomial
            .evaluate(records.velocity_coefficients[interval], normalized_time)
        ]
      end

      def component_count
        COMPONENT_COUNTS.fetch(@data_type) do
          raise UnsupportedError, "Unsupported SPK data type: #{@data_type}"
        end
      end

      Registry.register(:spk, 2, self)
      Registry.register(:spk, 3, self)
    end
  end
end
