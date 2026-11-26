# frozen_string_literal: true

require_relative "../../ephem"

module Ephem
  module Tasks
    class ValidateTestpo
      KERNELS = {
        "inpop21a" => {
          kernel: "kernels/inpop21a_excerpt.bsp",
          testpo: "data/testpo.INPOP21A_TDB"
        }
      }.freeze

      ASTRONOMICAL_UNIT_KM = 149_597_870.7
      TOLERANCE = 1e-13
      REPORTED_FAILURES_COUNT = 10

      TESTPO_BODIES = {
        1 => Core::Constants::Bodies::MERCURY_BARYCENTER,
        2 => Core::Constants::Bodies::VENUS_BARYCENTER,
        3 => Core::Constants::Bodies::EARTH,
        4 => Core::Constants::Bodies::MARS_BARYCENTER,
        5 => Core::Constants::Bodies::JUPITER_BARYCENTER,
        6 => Core::Constants::Bodies::SATURN_BARYCENTER,
        7 => Core::Constants::Bodies::URANUS_BARYCENTER,
        8 => Core::Constants::Bodies::NEPTUNE_BARYCENTER,
        9 => Core::Constants::Bodies::PLUTO_BARYCENTER,
        10 => Core::Constants::Bodies::MOON,
        11 => Core::Constants::Bodies::SUN,
        12 => Core::Constants::Bodies::SOLAR_SYSTEM_BARYCENTER,
        13 => Core::Constants::Bodies::EARTH_MOON_BARYCENTER
      }.freeze

      VELOCITY_COMPONENTS = (4..6)

      Row = Struct.new(
        :line,
        :julian_date,
        :target,
        :center,
        :component,
        :expected_value
      )

      def self.run(kernel:)
        paths = KERNELS.fetch(kernel)
        new(
          kernel_path: File.join(__dir__, paths.fetch(:kernel)),
          testpo_path: File.join(__dir__, paths.fetch(:testpo))
        ).run
      end

      def initialize(kernel_path:, testpo_path:)
        @kernel_path = kernel_path
        @testpo_path = testpo_path
      end

      def run
        rows = testpo_rows
        max_errors = {position: 0.0, velocity: 0.0}
        failures = []

        SPK.open(@kernel_path) do |spk|
          rows.each do |row|
            error = (computed_value(spk, row) - row.expected_value).abs
            kind = velocity?(row) ? :velocity : :position
            max_errors[kind] = [max_errors[kind], error].max
            failures << [row, error] if error > TOLERANCE
          end
        end

        puts report(rows.size, failures, max_errors)
        failures.empty?
      end

      private

      def testpo_rows
        File.foreach(@testpo_path)
          .drop_while { |line| !line.start_with?("EOT") }
          .drop(1)
          .map { |line| parse_row(line) }
      end

      def parse_row(line)
        _ephemeris, _date, julian_date, target, center, component, value =
          line.split
        Row.new(
          line: line.strip,
          julian_date: Float(julian_date),
          target: Integer(target),
          center: Integer(center),
          component: Integer(component),
          expected_value: Float(value)
        )
      end

      def computed_value(spk, row)
        state = spk.state_at(
          target: TESTPO_BODIES.fetch(row.target),
          center: TESTPO_BODIES.fetch(row.center),
          tdb: row.julian_date
        )
        components = state.position.to_a + state.velocity.to_a
        components.fetch(row.component - 1) / ASTRONOMICAL_UNIT_KM
      end

      def velocity?(row)
        VELOCITY_COMPONENTS.cover?(row.component)
      end

      def report(rows_count, failures, max_errors)
        title = File.basename(@testpo_path)
        lines = if failures.empty?
          ["#{rows_count} testpo validations passed (#{title})."]
        else
          [
            "#{failures.size} of #{rows_count} testpo validations failed " \
            "(#{title}), tolerance #{TOLERANCE}:",
            *failures.first(REPORTED_FAILURES_COUNT).map do |row, error|
              "  #{row.line} (error #{error})"
            end
          ]
        end
        lines << "Max position error (AU): #{max_errors[:position]}"
        lines << "Max velocity error (AU/day): #{max_errors[:velocity]}"
        lines.join("\n")
      end
    end
  end
end
