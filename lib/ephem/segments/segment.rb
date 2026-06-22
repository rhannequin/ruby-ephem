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

      def initialize(daf:, source:, descriptor:)
        super
        @data_loaded = false
        @data_lock = Mutex.new
      end

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
      end
      alias_method :state_at, :compute_and_differentiate

      private

      def component_count
        COMPONENT_COUNTS.fetch(@data_type) do
          raise "Unsupported data type: #{@data_type}"
        end
      end

      Registry.register(:spk, 2, self)
      Registry.register(:spk, 3, self)
    end
  end
end
