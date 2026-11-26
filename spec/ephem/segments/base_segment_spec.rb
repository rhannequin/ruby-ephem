# frozen_string_literal: true

RSpec.describe Ephem::Segments::BaseSegment do
  describe "#describe" do
    it "returns a concise description when verbose is false" do
      daf = double("daf")
      source = "DE-0421LE-0421"
      target = Ephem::Core::Constants::Bodies::EARTH_MOON_BARYCENTER
      center = Ephem::Core::Constants::Bodies::SOLAR_SYSTEM_BARYCENTER
      descriptor = [
        100.0,    # start_second
        200.0,    # end_second
        target,
        center,
        1,        # frame
        2,        # data_type
        0,        # start_i
        100       # end_i
      ]
      segment = described_class.new(
        daf: daf,
        source: source,
        descriptor: descriptor
      )

      expected = "2000-01-01..2000-01-01 Type 2 " \
        "Solar System Barycenter (0) -> Earth-Moon Barycenter (3)"
      expect(segment.describe).to eq(expected)
    end

    it "returns a detailed description when verbose is true" do
      daf = double("daf")
      source = "DE-0421LE-0421"
      target = Ephem::Core::Constants::Bodies::EARTH_MOON_BARYCENTER
      center = Ephem::Core::Constants::Bodies::SOLAR_SYSTEM_BARYCENTER
      descriptor = [
        100.0,
        200.0,
        target,
        center,
        1,
        2,
        0,
        100
      ]
      segment = described_class.new(
        daf: daf,
        source: source,
        descriptor: descriptor
      )

      expected = <<~DESCRIPTION.chomp
        2000-01-01..2000-01-01 Type 2 Solar System Barycenter (0) -> \
        Earth-Moon Barycenter (3)
        frame=1 source=DE-0421LE-0421
      DESCRIPTION
      expect(segment.describe(verbose: true)).to eq(expected)
    end

    it "falls back to a generic name for unknown bodies" do
      unknown_body_id = 2_000_001
      descriptor = [100.0, 200.0, unknown_body_id, 0, 1, 2, 0, 100]
      segment = described_class.new(
        daf: double("daf"),
        source: "DE-0421LE-0421",
        descriptor: descriptor
      )

      expect(segment.describe).to end_with("-> Unknown Target (2000001)")
    end

    it "names the time ephemeris pair of INPOP time kernels" do
      time_center = Ephem::Core::Constants::Bodies::TIME_CENTER
      tt_minus_tdb = Ephem::Core::Constants::Bodies::TT_MINUS_TDB
      descriptor = [100.0, 200.0, tt_minus_tdb, time_center, 1, 2, 0, 100]
      segment = described_class.new(
        daf: double("daf"),
        source: "INPOP21A",
        descriptor: descriptor
      )

      expect(segment.describe).to end_with(
        "Time Center (1000000000) -> TT-TDB (1000000001)"
      )
    end
  end

  describe "#compute" do
    it "raises UnsupportedError for an unimplemented data type" do
      segment = build_segment(data_type: 21)

      expect { segment.compute(2451545.0) }.to raise_error(
        Ephem::UnsupportedError, /compute\(\) for data type 21/
      )
    end
  end

  describe "#compute_and_differentiate" do
    it "raises UnsupportedError for an unimplemented data type" do
      segment = build_segment(data_type: 21)

      expect { segment.compute_and_differentiate(2451545.0) }
        .to raise_error(
          Ephem::UnsupportedError,
          /compute_and_differentiate\(\) for data type 21/
        )
    end
  end

  def build_segment(data_type:)
    descriptor = [100.0, 200.0, 3, 0, 1, data_type, 0, 100]

    described_class.new(
      daf: double("daf"),
      source: "DE-0421LE-0421",
      descriptor: descriptor
    )
  end
end
