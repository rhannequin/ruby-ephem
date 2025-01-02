# frozen_string_literal: true

module Ephem
  module Core
    module CalendarCalculations
      module_function

      def julian_to_gregorian(julian_date)
        # Convert Julian Date to Gregorian calendar date using the algorithm
        # from Fundamentals of Astrodynamics (Bate, Mueller, White) pg. 42

        # Adjust Julian Date and calculate integer and fractional parts
        jd = julian_date + 0.5  # Add 0.5 to Julian Date for correct rounding
        z = jd.floor            # Integer part of adjusted Julian Date
        f = jd - z              # Fractional part of adjusted Julian Date

        # Handle dates before and after the Gregorian calendar reform of 1582
        a = if z < 2299161 # 2299161 is the Julian Date of 1582-10-15T00:00:00Z
          z                # Use integer part directly for Julian calendar dates
        else
          # 1867216.25 is the Julian Date of 1500-03-01T00:00:00Z
          alpha = ((z - 1867216.25) / 36524.25).floor
          # Adjust for Gregorian calendar
          z + 1 + alpha - (alpha / 4).floor
        end

        # Calculate intermediate values
        # 1524 is the number of days from 1 BC to 1 AD
        b = a + 1524
        # 365.25 is the number of days in a Julian year
        c = ((b - 122.1) / 365.25).floor
        # Number of days since 1 BC
        d = (365.25 * c).floor
        # 30.6001 is the average number of days in a month
        e = ((b - d) / 30.6001).floor

        # Extract day, month, and year values from intermediate values
        # Fractional part gives the day of month
        day = b - d - (30.6001 * e).floor + f
        # Months are numbered from 1 (January) to 12 (December)
        month = (e < 14) ? e - 1 : e - 13
        # 4716 BC is the year of Julian Date 0
        year = (month > 2) ? c - 4716 : c - 4715

        [year, month, day.to_i]  # Return [year, month, day] as an array
      end

      def format_date(year, month, day)
        format("%d-%02d-%02d", year, month, day)
      end
    end
  end
end
