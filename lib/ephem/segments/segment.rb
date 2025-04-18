# frozen_string_literal: true

module Ephem
  module Segments
    # Manages data segments within SPICE kernel (SPK) files, providing methods
    # to compute positions and velocities of celestial bodies using Chebyshev
    # polynomial approximations.
    #
    # Each segment contains data for a specific celestial body (target) relative
    # to another body (center) within a specific time range. The data is stored
    # as Chebyshev polynomial coefficients that can be evaluated to obtain
    # position and velocity vectors.
    #
    # The class provides thread-safe data loading and caching mechanisms to
    # optimize performance while ensuring data consistency in multithreaded
    # environments.
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
    #   position = state.position  # Vector
    #   velocity = state.velocity  # Vector
    #
    # @see Ephem::Core::Vector
    # @see Ephem::Core::State
    # @see Ephem::Computation::ChebyshevPolynomial
    class Segment < BaseSegment
      COMPONENT_COUNTS = {
        2 => 3,  # Type 2: position (x, y, z)
        3 => 6   # Type 3: position (x, y, z) and velocity (vx, vy, vz)
      }.freeze

      # @param daf [Ephem::IO::DAF] DAF file object containing the segment data
      # @param source [String] Name of the source SPK file
      # @param descriptor [Array] Array containing segment metadata:
      #   - start_second [Float] Start time in seconds from J2000
      #   - end_second [Float] End time in seconds from J2000
      #   - target [Integer] NAIF ID of target body
      #   - center [Integer] NAIF ID of center body
      #   - frame [Integer] Reference frame ID
      #   - data_type [Integer] Type of data (2 for position, 3 for pos/vel)
      #   - start_i [Integer] Start index in DAF array
      #   - end_i [Integer] End index in DAF array
      def initialize(daf:, source:, descriptor:)
        super
        @data_loaded = false
        @data_lock = Mutex.new
      end

      # Computes the position of the target body relative to the center body at
      # the specified time.
      #
      # Uses Chebyshev polynomial approximation to interpolate the position from
      # stored coefficients. The computation is thread-safe and uses cached data
      # when available.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Ephem::Core::Vector] Position vector in kilometers
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      #
      # @example Computing Earth's position relative to Solar System Barycenter
      #   position = segment.compute(2451545.0)  # J2000 epoch
      def compute(tdb, tdb2 = 0.0)
        Core::Vector.new(*generate(tdb, tdb2).first)
      end
      alias_method :position_at, :compute

      # Computes both position and velocity vectors at the specified time.
      #
      # Uses Chebyshev polynomial approximation and its derivative to compute
      # both position and velocity. The computation is thread-safe and uses
      # cached data when available.
      #
      # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
      # @param tdb2 [Numeric] Optional fractional part of TDB date
      # @return [Ephem::Core::State, Array<Ephem::Core::State>] State object(s)
      #   containing position and velocity vectors. Returns array if input is
      #   array.
      # @raise [Ephem::OutOfRangeError] if time is outside segment coverage
      #
      # @example Computing Earth's state vector
      #   state = segment.compute_and_differentiate(2451545.0)
      #   position = state.position  # in kilometers
      #   velocity = state.velocity  # in kilometers/second
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
      end
      alias_method :state_at, :compute_and_differentiate

      # Clears cached coefficient data, forcing reload on next computation.
      #
      # This method is thread-safe and can be used to free memory or force
      # fresh data loading if needed.
      #
      # @return [void]
      def clear_data
        @data_lock.synchronize do
          @data_loaded = false
          @midpoints = nil
          @radii = nil
          @coefficients = nil
        end
      end

      private

      def load_data
        # Synchronize access to data loading using a mutex lock
        # to prevent race conditions in multithreaded environments
        @data_lock.synchronize do
          return if @data_loaded # Return early if data is already loaded

          component_count = determine_component_count
          coefficients_data = load_coefficient_data
          process_coefficient_data(coefficients_data, component_count)

          @data_loaded = true
        end
      end

      def determine_component_count
        COMPONENT_COUNTS.fetch(@data_type) do
          raise "Unsupported data type: #{@data_type}"
        end
      end

      def load_coefficient_data
        # Read metadata from the end of the segment
        # start_index: index of first coefficient in segment
        # end_index: index of last coefficient in segment
        # record_size: total size of each record (coefficients + 2)
        # segment_count: number of records in the segment
        metadata = @daf.read_array(@end_i - 3, @end_i)
        _start_index, _end_index, record_size, segment_count = metadata

        coefficient_count = ((record_size - 2) / determine_component_count).to_i
        coefficients_raw = @daf.map_array(@start_i, @end_i - 4)

        [
          coefficients_raw,
          record_size.to_i,
          segment_count.to_i,
          coefficient_count
        ]
      end

      def process_coefficient_data(data, component_count)
        coefficients_raw, record_size, segment_count, coefficient_count = data

        # Convert raw coefficient data to Numo::DFloat and reshape to 2D array.
        # Numo::NArray allows efficient numerical computations on arrays.
        # It provides ndarray data structures and supports various arithmetic
        # operations. Using Numo::DFloat ensures the array elements are 64-bit
        # floating point numbers.
        coefficients = Numo::DFloat.cast(coefficients_raw)
        coefficients = coefficients.reshape(segment_count, record_size)

        # Extract midpoints and radii from coefficient data
        # midpoints: array of times at middle of each record's interval
        # radii: array of half the interval length for each record
        @midpoints = coefficients[0...segment_count, 0]
        @radii = coefficients[0...segment_count, 1]

        # Extract Chebyshev polynomial coefficients and reshape to 3D array
        # dimensions: (coefficient_index, component_index, segment_index)
        coeffs = coefficients[0...segment_count, 2..-1]
        @coefficients = coeffs.reshape(
          segment_count,
          component_count,
          coefficient_count
        )
          .transpose(2, 1, 0)
      end

      def convert_to_seconds(tdb, tdb2)
        case tdb
        when Array, Numo::NArray
          tdb.map { |t| time_to_seconds(t, tdb2) }
        else
          time_to_seconds(tdb, tdb2)
        end
      end

      def time_to_seconds(time, offset)
        (time - Time::J2000_EPOCH) *
          Time::SECONDS_PER_DAY +
          offset *
            Time::SECONDS_PER_DAY
      end

      def generate(tdb, tdb2)
        load_data
        tdb_seconds = convert_to_seconds(tdb, tdb2)

        case tdb_seconds
        when Numeric
          generate_single(tdb_seconds)
        else
          generate_multiple(tdb_seconds)
        end
      end

      def generate_single(tdb_seconds)
        interval = find_interval(tdb_seconds)
        normalized_time = compute_normalized_time(tdb_seconds, interval)
        coeffs = @coefficients[true, true, interval]

        position = Computation::ChebyshevPolynomial.new(
          coefficients: coeffs,
          normalized_time: normalized_time
        ).evaluate

        velocity = Computation::ChebyshevPolynomial.new(
          coefficients: coeffs,
          normalized_time: normalized_time,
          radius: @radii[interval]
        ).evaluate_derivative

        [position.to_a, velocity.to_a]
      end

      def generate_multiple(tdb_seconds)
        positions = []
        velocities = []

        tdb_seconds.each do |time|
          pos, vel = generate_single(time)
          positions << pos
          velocities << vel
        end

        [positions, velocities]
      end

      def find_interval(tdb_seconds)
        interval = (0...@midpoints.size).find do |i|
          time_in_interval?(tdb_seconds, i)
        end

        interval or raise OutOfRangeError.new(
          "Time #{tdb_seconds} is outside the coverage of this segment",
          tdb_seconds
        )
      end

      def time_in_interval?(time, interval)
        min_time = @midpoints[interval] - @radii[interval]
        max_time = @midpoints[interval] + @radii[interval]
        time.between?(min_time, max_time)
      end

      def compute_normalized_time(time_seconds, interval)
        (time_seconds - @midpoints[interval]) / @radii[interval]
      end

      Registry.register(2, self)
      Registry.register(3, self)
    end
  end
end
