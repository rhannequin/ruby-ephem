# frozen_string_literal: true

module Ephem
  module Core
    module CalendarCalculations
      module_function

      # Converts a Julian Date to a Gregorian calendar date
      #
      # @param julian_date [Float] The Julian Date to convert. The Julian Date
      #   is the number of days since noon on January 1, 4713 BCE (on the Julian
      #   calendar).
      #
      # @return [Array<Integer>] An array containing [year, month, day].
      #   For dates BCE, the year will be negative
      #   (-1 = 2 BCE, -2 = 3 BCE, etc.)
      #
      # @example Converting a date after Gregorian reform
      #   julian_to_gregorian(2460000.0)  # => [2023, 2, 24]
      #
      # @example Converting a date before Gregorian reform
      #   julian_to_gregorian(2299160.0)  # => [1582, 10, 4]
      #
      # @example Converting a BCE date
      #   julian_to_gregorian(1721056.5)  # => [-1, 12, 31]
      #
      # @note The algorithm handles the transition between Julian and Gregorian
      #   calendars at 1582-10-15 (Julian Date 2299161). Dates on or after this
      #   are interpreted as Gregorian calendar dates, while earlier dates are
      #   interpreted as Julian calendar dates.
      def julian_to_gregorian(julian_date)
        # Convert Julian Date to Gregorian calendar date using the algorithm
        # from Fundamentals of Astrodynamics (Bate, Mueller, White) pg. 42

        shifted_date = julian_date + 0.5
        day_number = shifted_date.floor
        day_fraction = shifted_date - day_number

        # 2299161 is the Julian Date of 1582-10-15T00:00:00Z
        calendar_day_number = if day_number < 2299161
          day_number
        else
          # 1867216.25 is the Julian Date of 1500-03-01T00:00:00Z
          elapsed_centuries = ((day_number - 1867216.25) / 36524.25).floor
          day_number + 1 + elapsed_centuries - (elapsed_centuries / 4).floor
        end

        days_since_epoch = calendar_day_number + 1524
        year_count = ((days_since_epoch - 122.1) / 365.25).floor
        days_in_whole_years = (365.25 * year_count).floor
        month_count = ((days_since_epoch - days_in_whole_years) / 30.6001).floor

        day = days_since_epoch - days_in_whole_years -
          (30.6001 * month_count).floor + day_fraction
        month = (month_count < 14) ? month_count - 1 : month_count - 13
        # 4716 BC is the year of Julian Date 0
        year = (month > 2) ? year_count - 4716 : year_count - 4715

        [year, month, day.to_i]
      end

      # Formats a calendar date as YYYY-MM-DD
      #
      # @param year [Integer] The year (negative for BCE)
      # @param month [Integer] The month (1-12)
      # @param day [Integer] The day of the month
      #
      # @return [String] The formatted date string
      #
      # @example Formatting a modern date
      #   format_date(2023, 2, 18)  # => "2023-02-18"
      #
      # @example Formatting a BCE date
      #   format_date(-44, 3, 15)   # => "-44-03-15"
      #
      # @example Formatting with single-digit values
      #   format_date(9, 3, 4)      # => "9-03-04"
      def format_date(year, month, day)
        format("%d-%02d-%02d", year, month, day)
      end
    end
  end
end
