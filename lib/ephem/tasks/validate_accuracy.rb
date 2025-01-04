# frozen_string_literal: true

require "csv"
require "./lib/ephem"

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

      ERROR_MARGIN = 0.000002 # 2 centimeters

      def self.run(date:, kernel:, target:)
        new.run(date: date, kernel: kernel, target: target)
      end

      def run(date:, kernel:, target:)
        @start_date = date
        @kernel_name = kernel
        @target = target.to_i

        perform_task
        puts "#{validations_count} validation passed."
        true
      rescue ValidationError => e
        puts "Error occurred: #{e.message}"
        false
      end

      private

      def perform_task
        ::CSV.foreach(csv_file_path, headers: true).each do |row|
          jd = row["julian_date"].to_i
          center = row["center"].to_i
          x = row["x"].to_f
          y = row["y"].to_f
          z = row["z"].to_f
          vx = row["vx"].to_f
          vy = row["vy"].to_f
          vz = row["vz"].to_f

          kernels[@kernel_name] ||= Ephem::SPK.open(kernel_path)
          kernel = kernels[@kernel_name]

          segment = kernel[center, @target]

          state = segment.compute_and_differentiate(jd)
          position = state.position
          velocity = state.velocity

          delta_x = (x - position.x).abs
          delta_y = (y - position.y).abs
          delta_z = (z - position.z).abs
          delta_vx = (vx - velocity.x).abs
          delta_vy = (vy - velocity.y).abs
          delta_vz = (vz - velocity.z).abs

          if [delta_x, delta_y, delta_z, delta_vx, delta_vy, delta_vz].any? { _1 > ERROR_MARGIN }
            raise ValidationError,
              "Error for #{@kernel_name} at #{jd} with target #{@target}"
          end
        end
      end

      def current_directory
        File.dirname(__FILE__)
      end

      def csv_file_path
        current_directory +
          "/" +
          CSV_FILE +
          "_#{@start_date}" \
          "_#{@kernel_name}" \
          "_#{@target}.csv"
      end

      def validations_count
        `wc -l "#{csv_file_path}"`.strip.split(" ")[0].to_i
      end

      def kernel_path
        name = KERNELS.fetch(@kernel_name)
        current_directory + "/" + KERNELS_DIR + name + ".bsp"
      end

      def kernels
        @kernels ||= {}
      end
    end
  end
end
