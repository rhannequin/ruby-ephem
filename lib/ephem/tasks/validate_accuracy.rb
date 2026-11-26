# frozen_string_literal: true

require "csv"
require_relative "../../ephem"

module Ephem
  module Tasks
    class ValidateAccuracy
      class ValidationError < StandardError; end

      KERNELS_DIR = "kernels/"
      CSV_FILE = "data/jplephem"

      KERNELS = {
        "de405" => "de405_excerpt",
        "de421" => "de421_excerpt",
        "de430t" => "de430t_excerpt",
        "de440s" => "de440s_excerpt"
      }.freeze

      CENTER = 0

      POSITION_ERROR_MARGIN = 0.0
      VELOCITY_ERROR_MARGIN = 0.000000002

      POSITION_KEYS = %i[dx dy dz].freeze
      VELOCITY_KEYS = %i[dvx dvy dvz].freeze

      def self.run(date:, kernel:, target:)
        new.run(date: date, kernel: kernel, target: target)
      end

      def run(date:, kernel:, target:)
        @start_time = Time.now
        @start_date = date
        @kernel_name = kernel
        @target = target.to_i
        @max_errors = (POSITION_KEYS + VELOCITY_KEYS).to_h { |key| [key, 0] }
        @validations_count = 0

        perform_task
        @end_time = Time.now

        puts output

        true
      rescue ValidationError => error
        puts "Error occurred: #{error.message}"
        puts max_errors_output
        false
      ensure
        @kernel&.close
      end

      private

      def perform_task
        ::CSV.foreach(csv_file_path, headers: true).each do |row|
          validate_row(row)
          @validations_count += 1
        end
      end

      def validate_row(row)
        julian_date = row["julian_date"].to_f
        state = kernel[CENTER, @target].compute_and_differentiate(julian_date)

        position_errors = component_errors(
          state.position, row.values_at("x", "y", "z")
        )
        velocity_errors = component_errors(
          state.velocity, row.values_at("vx", "vy", "vz")
        )
        record_max_errors(POSITION_KEYS, position_errors)
        record_max_errors(VELOCITY_KEYS, velocity_errors)

        if position_errors.any? { |error| error > POSITION_ERROR_MARGIN }
          raise ValidationError, failure_message("Position", julian_date)
        end

        if velocity_errors.any? { |error| error > VELOCITY_ERROR_MARGIN }
          raise ValidationError, failure_message("Velocity", julian_date)
        end
      end

      def component_errors(vector, expected_values)
        vector.to_a.zip(expected_values).map do |computed, expected|
          (expected.to_f - computed).abs
        end
      end

      def record_max_errors(keys, errors)
        keys.zip(errors).each do |key, error|
          @max_errors[key] = [error, @max_errors[key]].max
        end
      end

      def failure_message(quantity, julian_date)
        "#{quantity} error for #{@kernel_name} at #{julian_date} " \
          "with target #{@target}"
      end

      def kernel
        @kernel ||= Ephem::SPK.open(kernel_path)
      end

      def current_directory
        File.dirname(__FILE__)
      end

      def csv_file_path
        File.join(
          current_directory,
          "#{CSV_FILE}_#{@start_date}_#{@kernel_name}_#{@target}.csv"
        )
      end

      def kernel_path
        file_name = KERNELS.fetch(@kernel_name)
        File.join(current_directory, KERNELS_DIR, "#{file_name}.bsp")
      end

      def output
        duration = (@end_time - @start_time).to_i
        title = "#{@kernel_name}/2000-2050/#{@target}"
        "#{@validations_count} validations passed (#{title}) " \
          "in #{duration} seconds.\n#{max_errors_output}"
      end

      def max_errors_output
        "Max position errors (km): #{format_errors(POSITION_KEYS)}\n" \
          "Max velocity errors (km/day): #{format_errors(VELOCITY_KEYS)}"
      end

      def format_errors(keys)
        keys.map { |key| "#{key}=#{@max_errors[key]}" }.join(", ")
      end
    end
  end
end
