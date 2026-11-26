# frozen_string_literal: true

module Ephem
  module Segments
    # Shared evaluation machinery for DAF "type 2" Chebyshev segments.
    module ChebyshevType2
      include Core::Constants

      Records = Struct.new(
        :midpoints,
        :radii,
        :coefficients,
        :velocity_coefficients,
        keyword_init: true
      )

      def initialize(...)
        super
        @records = nil
        @data_lock = Mutex.new
      end

      # @return [void]
      def clear_data
        @data_lock.synchronize { @records = nil }
      end

      private

      def load_data
        @records || @data_lock.synchronize do
          @records ||= process_coefficient_data(load_coefficient_data)
        end
      end

      def load_coefficient_data
        metadata = @daf.read_array(@end_i - 3, @end_i)
        _start_index, _end_index, record_size, segment_count = metadata

        coefficient_count = ((record_size - 2) / component_count).to_i
        coefficients_raw = @daf.read_array(@start_i, @end_i - 4)

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

        midpoints = coefficients.map { |row| row[0] }.freeze
        radii = coefficients.map { |row| row[1] }.freeze
        n_terms = coefficient_count
        n_components = component_count

        terms = Array.new(segment_count) do |i|
          row = coefficients[i][2..]
          Array.new(n_terms) do |k|
            Array.new(n_components) do |j|
              row[k + j * n_terms]
            end
          end
        end

        Records.new(
          midpoints: midpoints,
          radii: radii,
          coefficients: terms.freeze,
          velocity_coefficients: nil
        ).freeze
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

      def generate_position(records, tdb_seconds)
        interval = find_interval(records, tdb_seconds)
        normalized_time =
          compute_normalized_time(records, tdb_seconds, interval)
        coeffs = records.coefficients[interval]
        Computation::ChebyshevPolynomial.evaluate(coeffs, normalized_time)
      end

      def generate_single(records, tdb_seconds)
        interval = find_interval(records, tdb_seconds)
        normalized_time =
          compute_normalized_time(records, tdb_seconds, interval)

        coeffs = records.coefficients[interval] # already [n_terms][3]
        Computation::ChebyshevPolynomial.evaluate_with_derivative(
          coeffs,
          normalized_time,
          records.radii[interval]
        )
      end

      def generate_multiple(records, tdb_seconds)
        tdb_seconds.map { |time| generate_single(records, time) }
      end

      def find_interval(records, tdb_seconds)
        last_interval = @last_interval
        if last_interval &&
            time_in_interval?(records, tdb_seconds, last_interval)
          return last_interval
        end

        midpoints = records.midpoints
        radii = records.radii
        left = 0
        right = midpoints.size - 1

        while left <= right
          mid = (left + right) / 2
          midpoint = midpoints[mid]
          radius = radii[mid]
          min_time = midpoint - radius
          max_time = midpoint + radius

          if tdb_seconds < min_time
            right = mid - 1
          elsif tdb_seconds > max_time
            left = mid + 1
          else
            @last_interval = mid
            return mid
          end
        end

        raise out_of_range_error(
          [Time::J2000_EPOCH + tdb_seconds / Time::SECONDS_PER_DAY]
        )
      end

      def out_of_range_error(times)
        Coverage.out_of_range_error(
          times: times,
          label: label,
          ranges: [[@start_jd, @end_jd]]
        )
      end

      def request_out_of_range_error(records, error, tdb, tdb2)
        times = uncovered_times(records, tdb, tdb2)
        times.empty? ? error : out_of_range_error(times)
      end

      def uncovered_times(records, tdb, tdb2)
        Array(tdb).filter_map do |time|
          tdb_seconds = time_to_seconds(time, tdb2)
          time + tdb2 unless covered_by_records?(records, tdb_seconds)
        end
      end

      def covered_by_records?(records, tdb_seconds)
        midpoints = records.midpoints
        radii = records.radii
        interval = (0...midpoints.size).bsearch do |index|
          midpoints[index] + radii[index] >= tdb_seconds
        end
        interval && time_in_interval?(records, tdb_seconds, interval)
      end

      def time_in_interval?(records, time, interval)
        midpoint = records.midpoints[interval]
        radius = records.radii[interval]
        time.between?(midpoint - radius, midpoint + radius)
      end

      def compute_normalized_time(records, time_seconds, interval)
        (time_seconds - records.midpoints[interval]) / records.radii[interval]
      end
    end
  end
end
