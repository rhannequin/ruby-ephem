# frozen_string_literal: true

RSpec.describe Ephem::Core::CalendarCalculations do
  describe ".julian_to_gregorian" do
    it "converts a Julian Date to Gregorian calendar for dates after 1582-10-15" do
      result = described_class.julian_to_gregorian(2460000) # 2023-02-24

      expect(result).to eq([2023, 2, 24])
    end

    it "converts a Julian Date to Gregorian calendar for dates before 1582-10-15" do
      result = described_class.julian_to_gregorian(2299160) # 1582-10-04

      expect(result).to eq([1582, 10, 4])
    end

    it "handles the Gregorian calendar reform transition date correctly" do
      result = described_class.julian_to_gregorian(2299161) # 1582-10-15

      expect(result).to eq([1582, 10, 15])
    end

    it "handles dates in early Julian calendar correctly" do
      result = described_class.julian_to_gregorian(1721423.5) # 0001-01-01

      expect(result).to eq([1, 1, 1])
    end

    it "handles fractional Julian Dates correctly" do
      # 2023-02-24 at 06:00 UTC
      result = described_class.julian_to_gregorian(2460000.25)

      expect(result).to eq([2023, 2, 24])
    end

    it "handles negative years (BCE dates) correctly" do
      # -0001-12-31 (2 BCE)
      result = described_class.julian_to_gregorian(1721056.5)

      expect(result).to eq([-1, 12, 31])
    end
  end

  describe ".format_date" do
    it "formats positive years correctly" do
      result = described_class.format_date(2023, 2, 18)

      expect(result).to eq("2023-02-18")
    end

    it "formats negative years (BCE) correctly" do
      result = described_class.format_date(-44, 3, 15)

      expect(result).to eq("-44-03-15")
    end

    it "formats single-digit months and days with leading zeros" do
      result = described_class.format_date(9, 3, 4)

      expect(result).to eq("9-03-04")
    end
  end
end
