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
        load_data
        tdb_seconds = convert_to_seconds(tdb, tdb2)

        case tdb_seconds
        when Numeric
          position = generate_position(tdb_seconds)
          Core::Vector.new(position[0], position[1], position[2])
        else
          tdb_seconds.map do |t|
            position = generate_position(t)
            Core::Vector.new(position[0], position[1], position[2])
          end
        end
      rescue OutOfRangeError => error
        raise request_out_of_range_error(error, tdb, tdb2), cause: nil
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
        load_data
        tdb_seconds = convert_to_seconds(tdb, tdb2)

        case tdb_seconds
        when Numeric
          pos_array, vel_array = generate_single(tdb_seconds)
          Core::State.new(
            Core::Vector.new(pos_array[0], pos_array[1], pos_array[2]),
            Core::Vector.new(vel_array[0], vel_array[1], vel_array[2])
          )
        else
          generate_multiple(tdb_seconds).map do |pos_array, vel_array|
            Core::State.new(
              Core::Vector.new(pos_array[0], pos_array[1], pos_array[2]),
              Core::Vector.new(vel_array[0], vel_array[1], vel_array[2])
            )
          end
        end
      rescue OutOfRangeError => error
        raise request_out_of_range_error(error, tdb, tdb2), cause: nil
      end
      alias_method :state_at, :compute_and_differentiate

      # @return [void]
      def clear_data
        @data_lock.synchronize do
          @data_loaded = false
          @midpoints = nil
          @radii = nil
          @coefficients = nil
          @velocity_coefficients = nil
        end
      end

      private

      def process_coefficient_data(data)
        super
        return unless @data_type == 3

        @velocity_coefficients = @coefficients.map do |terms|
          terms.map do |term|
            [
              term[3] * Time::SECONDS_PER_DAY,
              term[4] * Time::SECONDS_PER_DAY,
              term[5] * Time::SECONDS_PER_DAY
            ]
          end
        end
        @coefficients = @coefficients.map do |terms|
          terms.map { |term| term.first(3) }
        end
      end

      def generate_single(tdb_seconds)
        return super unless @data_type == 3

        interval = find_interval(tdb_seconds)
        normalized_time = compute_normalized_time(tdb_seconds, interval)
        [
          Computation::ChebyshevPolynomial
            .evaluate(@coefficients[interval], normalized_time),
          Computation::ChebyshevPolynomial
            .evaluate(@velocity_coefficients[interval], normalized_time)
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
