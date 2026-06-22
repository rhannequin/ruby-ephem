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

    it "raises OutOfRangeError when no segment covers the time" do
      segment = build_position_segment(covers: 0.0..1.0)
      group = described_class.new([segment])

      expect { group.compute(150.0) }
        .to raise_error(Ephem::OutOfRangeError)
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
      target: 301
    )
    allow(segment).to receive(:covers?) { |time| covers.cover?(time) }
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
      reference_frame: 1
    )
    allow(segment).to receive(:covers?) { |time| covers.cover?(time) }
    segment
  end
end
