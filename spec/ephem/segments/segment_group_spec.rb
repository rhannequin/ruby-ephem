# frozen_string_literal: true

RSpec.describe Ephem::Segments::PositionGroup do
  describe "#compute" do
    it "routes a scalar time to the covering segment" do
      early = build_position_segment(covers: 0.0..99.0)
      late = build_position_segment(covers: 100.0..200.0)
      allow(late).to receive(:compute).with(150.0, 0.0).and_return(:late)
      group = described_class.new([early, late])

      expect(group.compute(150.0)).to eq(:late)
    end

    it "routes each time of an array to its segment, in order" do
      early = build_position_segment(covers: 0.0..99.0)
      late = build_position_segment(covers: 100.0..200.0)
      allow(early).to receive(:compute).with([10.0], 0.0).and_return([:a])
      allow(late).to receive(:compute).with([150.0], 0.0).and_return([:b])
      group = described_class.new([early, late])

      expect(group.compute([10.0, 150.0])).to eq([:a, :b])
    end

    it "raises OutOfRangeError naming the time, pair and coverage" do
      early = build_position_segment(covers: 2451545.0..2451546.0)
      late = build_position_segment(covers: 2451546.0..2451547.0)
      group = described_class.new([early, late])

      expect { group.compute(2451550.0) }.to raise_error(
        Ephem::OutOfRangeError,
        "JD 2451550.0 (2000-01-06) is outside the coverage of " \
        "Earth-Moon Barycenter (3) -> Moon (301), " \
        "which covers JD 2451545.0..2451547.0 (2000-01-01..2000-01-03)"
      )
    end

    it "lists disjoint coverage ranges separately" do
      early = build_position_segment(covers: 2451545.0..2451546.0)
      late = build_position_segment(covers: 2451550.0..2451551.0)
      group = described_class.new([early, late])

      expect { group.compute(2451548.0) }.to raise_error(
        Ephem::OutOfRangeError, /2451546.0 \(.*\), JD 2451550.0/
      )
    end

    it "reports the time with its tdb2 fraction" do
      segment = build_position_segment(covers: 2451545.0..2451546.0)
      group = described_class.new([segment, segment])

      expect { group.compute(2451546.0, 0.5) }
        .to raise_error(Ephem::OutOfRangeError) do |error|
          expect(error.out_of_range_times).to eq([2451546.5])
        end
    end

    it "reports every uncovered time of an array" do
      segment = build_position_segment(covers: 2451545.0..2451546.0)
      group = described_class.new([segment, segment])

      expect { group.compute([2451540.0, 2451545.5, 2451550.0]) }
        .to raise_error(
          Ephem::OutOfRangeError,
          /\AJD 2451540.0 \(1999-12-27\) and 1 other time are outside/
        ) do |error|
          expect(error.out_of_range_times).to eq([2451540.0, 2451550.0])
        end
    end
  end

  describe "#center and #target" do
    it "delegate to the first segment" do
      segment = build_position_segment(covers: 0.0..1.0)
      group = described_class.new([segment])

      expect(group.center).to eq(0)
      expect(group.target).to eq(301)
    end
  end

  describe "#clear_data" do
    it "clears data on every segment" do
      first = build_position_segment(covers: 0.0..1.0)
      second = build_position_segment(covers: 0.0..1.0)
      group = described_class.new([first, second])

      expect(first).to receive(:clear_data)
      expect(second).to receive(:clear_data)

      group.clear_data
    end
  end

  def build_position_segment(covers:)
    segment = instance_double(
      Ephem::Segments::Segment,
      center: 0,
      target: 301,
      label: "Earth-Moon Barycenter (3) -> Moon (301)",
      start_jd: covers.begin,
      end_jd: covers.end
    )
    allow(segment).to receive(:covers?) do |time, fraction = 0.0|
      covers.cover?(time + fraction)
    end
    allow(segment).to receive(:clear_data)
    segment
  end
end

RSpec.describe Ephem::Segments::OrientationGroup do
  describe "#angles_at" do
    it "routes to the covering segment" do
      early = build_orientation_segment(covers: 0.0..99.0)
      late = build_orientation_segment(covers: 100.0..200.0)
      allow(early).to receive(:angles_at).with(10.0, 0.0).and_return(:a)
      group = described_class.new([early, late])

      expect(group.angles_at(10.0)).to eq(:a)
    end
  end

  describe "#orientation_at" do
    it "raises OutOfRangeError naming the frames" do
      segment = build_orientation_segment(covers: 2451545.0..2451546.0)
      group = described_class.new([segment, segment])

      expect { group.orientation_at(2451550.0) }.to raise_error(
        Ephem::OutOfRangeError,
        /outside the coverage of frame 31008 relative to frame 1,/
      )
    end
  end

  describe "#body and #reference_frame" do
    it "delegate to the first segment" do
      segment = build_orientation_segment(covers: 0.0..1.0)
      group = described_class.new([segment])

      expect(group.body).to eq(31008)
      expect(group.reference_frame).to eq(1)
    end
  end

  def build_orientation_segment(covers:)
    segment = instance_double(
      Ephem::Segments::OrientationSegment,
      body: 31008,
      reference_frame: 1,
      label: "frame 31008 relative to frame 1",
      start_jd: covers.begin,
      end_jd: covers.end
    )
    allow(segment).to receive(:covers?) { |time| covers.cover?(time) }
    segment
  end
end
