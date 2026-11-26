# frozen_string_literal: true

RSpec.describe Ephem::Segments::Coverage do
  describe ".out_of_range_error" do
    it "describes a single time, the label and the covered range" do
      error = described_class.out_of_range_error(
        times: [2400000.5],
        label: "Earth-Moon Barycenter (3) -> Moon (301)",
        ranges: [[2433264.5, 2469808.5]]
      )

      expect(error).to be_a(Ephem::OutOfRangeError)
      expect(error.message).to eq(
        "JD 2400000.5 (1858-11-17) is outside the coverage of " \
        "Earth-Moon Barycenter (3) -> Moon (301), " \
        "which covers JD 2433264.5..2469808.5 (1949-12-14..2050-01-02)"
      )
      expect(error.out_of_range_times).to eq([2400000.5])
    end

    it "counts the other uncovered times" do
      error = described_class.out_of_range_error(
        times: [2400000.5, 2400001.5, 2400002.5],
        label: "Moon",
        ranges: [[2433264.5, 2469808.5]]
      )

      expect(error.message).to start_with(
        "JD 2400000.5 (1858-11-17) and 2 other times are outside"
      )
      expect(error.out_of_range_times)
        .to eq([2400000.5, 2400001.5, 2400002.5])
    end

    it "leaves out the calendar date of a non-finite time" do
      error = described_class.out_of_range_error(
        times: [Float::INFINITY],
        label: "Moon",
        ranges: [[2433264.5, 2469808.5]]
      )

      expect(error.message)
        .to start_with("JD Infinity is outside the coverage of Moon")
    end

    it "merges contiguous ranges and keeps disjoint ones apart" do
      error = described_class.out_of_range_error(
        times: [2451560.0],
        label: "Moon",
        ranges: [
          [2451550.0, 2451551.0],
          [2451545.0, 2451546.0],
          [2451546.0, 2451547.0]
        ]
      )

      expect(error.message).to end_with(
        "covers JD 2451545.0..2451547.0 (2000-01-01..2000-01-03), " \
        "JD 2451550.0..2451551.0 (2000-01-06..2000-01-07)"
      )
    end
  end
end
