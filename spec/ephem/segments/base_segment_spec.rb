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

      expected = "2000-01-01..2000-01-01 Type 2 Solar System Barycenter (0) -> Earth-moon Barycenter (3)"
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
        2000-01-01..2000-01-01 Type 2 Solar System Barycenter (0) -> Earth-moon Barycenter (3)
        frame=1 source=DE-0421LE-0421
      DESCRIPTION
      expect(segment.describe(verbose: true)).to eq(expected)
    end
  end
end
