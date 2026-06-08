# frozen_string_literal: true

module Ephem
  module Segments
    # Shared evaluation machinery for DAF "type 2" Chebyshev segments.
    module ChebyshevType2
      include Core::Constants

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
        @data_lock.synchronize do
          return if @data_loaded

          process_coefficient_data(load_coefficient_data)

          @data_loaded = true
        end
      end

      def load_coefficient_data
        metadata = @daf.read_array(@end_i - 3, @end_i)
        _start_index, _end_index, record_size, segment_count = metadata

        coefficient_count = ((record_size - 2) / component_count).to_i
        coefficients_raw = @daf.map_array(@start_i, @end_i - 4)

        [
          coefficients_raw,
          record_size.to_i,
          segment_count.to_i,
          coefficient_count
        ]
      end

      def process_coefficient_data(data)
        coefficients_raw, record_size, segment_count, coefficient_count = data

        coefficients = coefficients_raw.each_slice(record_size).to_a

        @midpoints = coefficients.map { |row| row[0] }
        @radii = coefficients.map { |row| row[1] }
        n_terms = coefficient_count
        n_components = component_count

        @coefficients = Array.new(segment_count) do |i|
          row = coefficients[i][2..]
          Array.new(n_terms) do |k|
            Array.new(n_components) do |j|
              row[k + j * n_terms]
            end
          end
        end
      end

      def convert_to_seconds(tdb, tdb2)
        case tdb
        when Array
          tdb.map { |t| time_to_seconds(t, tdb2) }
        else
          time_to_seconds(tdb, tdb2)
        end
      end

      def time_to_seconds(time, offset)
        (time - Time::J2000_EPOCH + offset) * Time::SECONDS_PER_DAY
      end

      def generate_position(tdb_seconds)
        interval = find_interval(tdb_seconds)
        normalized_time = compute_normalized_time(tdb_seconds, interval)
        coeffs = @coefficients[interval]
        Computation::ChebyshevPolynomial.evaluate(coeffs, normalized_time)
      end

      def generate_single(tdb_seconds)
        interval = find_interval(tdb_seconds)
        normalized_time = compute_normalized_time(tdb_seconds, interval)

        coeffs = @coefficients[interval] # already [n_terms][3]
        position = Computation::ChebyshevPolynomial.evaluate(
          coeffs,
          normalized_time
        )
        velocity = Computation::ChebyshevPolynomial.evaluate_derivative(
          coeffs,
          normalized_time,
          @radii[interval]
        )
        [position, velocity]
      end

      def generate_multiple(tdb_seconds)
        tdb_seconds.map { |time| generate_single(time) }
      end

      def find_interval(tdb_seconds)
        left = 0
        right = @midpoints.size - 1

        if @last_interval && time_in_interval?(tdb_seconds, @last_interval)
          return @last_interval
        end

        while left <= right
          mid = (left + right) / 2
          min_time = @midpoints[mid] - @radii[mid]
          max_time = @midpoints[mid] + @radii[mid]

          if tdb_seconds < min_time
            right = mid - 1
          elsif tdb_seconds > max_time
            left = mid + 1
          else
            @last_interval = mid
            return mid
          end
        end

        raise OutOfRangeError.new(
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
    end
  end
end
