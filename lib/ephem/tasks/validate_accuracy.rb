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

      POSITION_ERROR_MARGIN = 0.0 # exact match
      VELOCITY_ERROR_MARGIN = 0.000000002 # 0.002 mm/s

      def self.run(date:, kernel:, target:)
        new.run(date: date, kernel: kernel, target: target)
      end

      def run(date:, kernel:, target:)
        @start_time = Time.now
        @start_date = date
        @kernel_name = kernel
        @target = target.to_i
        @max_errors = {dx: 0, dy: 0, dz: 0, dvx: 0, dvy: 0, dvz: 0}

        perform_task
        @end_time = Time.now

        puts output

        true
      rescue ValidationError => e
        puts "Error occurred: #{e.message}"
        puts max_errors_output
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

          @max_errors[:dx] = [delta_x, @max_errors[:dx]].max
          @max_errors[:dy] = [delta_y, @max_errors[:dy]].max
          @max_errors[:dz] = [delta_z, @max_errors[:dz]].max
          @max_errors[:dvx] = [delta_vx, @max_errors[:dvx]].max
          @max_errors[:dvy] = [delta_vy, @max_errors[:dvy]].max
          @max_errors[:dvz] = [delta_vz, @max_errors[:dvz]].max

          if [delta_x, delta_y, delta_z].any? { _1 > POSITION_ERROR_MARGIN }
            raise ValidationError,
              "Position error for #{@kernel_name} at #{jd} with target #{@target}"
          end

          if [delta_vx, delta_vy, delta_vz].any? { _1 > VELOCITY_ERROR_MARGIN }
            raise ValidationError,
              "Velocity error for #{@kernel_name} at #{jd} with target #{@target}"
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

      def output
        duration = (@end_time - @start_time).to_i
        title = "#{@kernel_name}/2000-2050/#{@target}"
        "#{validations_count} validation passed (#{title}) in #{duration} seconds.\n#{max_errors_output}"
      end

      def max_errors_output
        pos = @max_errors.slice(:dx, :dy, :dz)
        vel = @max_errors.slice(:dvx, :dvy, :dvz)
        "Max position errors (km): #{pos.map { |k, v| "#{k}=#{v}" }.join(", ")}\n" \
          "Max velocity errors (km/s): #{vel.map { |k, v| "#{k}=#{v}" }.join(", ")}"
      end
    end
  end
end
