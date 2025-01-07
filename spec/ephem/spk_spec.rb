# frozen_string_literal: true

RSpec.describe Ephem::SPK do
  describe ".open" do
    it "creates a new SPK instance with a DAF from the given path" do
      file_double = instance_double(File)
      daf_double = instance_double(Ephem::IO::DAF)

      allow(File).to receive(:open)
        .with("spk_file.bsp", "rb")
        .and_return(file_double)

      allow(Ephem::IO::DAF).to receive(:new)
        .with(file_double)
        .and_return(daf_double)

      allow(daf_double).to receive(:summaries)
        .and_return([])

      spk = described_class.open("spk_file.bsp")

      expect(spk).to be_an_instance_of(described_class)
    end
  end

  describe "#initialize" do
    it "raises ArgumentError when DAF is nil" do
      expect { described_class.new(daf: nil) }.to raise_error(
        ArgumentError,
        "DAF cannot be nil"
      )
    end
  end

  describe "#close" do
    it "closes the DAF and clears segment data" do
      daf = instance_double(Ephem::IO::DAF)
      segment1 = instance_double(
        Ephem::Segments::BaseSegment,
        center: 399,
        target: 301
      )
      segment2 = instance_double(
        Ephem::Segments::BaseSegment,
        center: 399,
        target: 302
      )

      descriptor1 = double("descriptor1")
      descriptor2 = double("descriptor2")
      allow(descriptor1).to receive(:[])
        .with(described_class::DATA_TYPE_IDENTIFIER)
        .and_return(2)
      allow(descriptor2).to receive(:[])
        .with(described_class::DATA_TYPE_IDENTIFIER)
        .and_return(2)

      allow(daf).to receive(:summaries).and_return([
        [double("source1"), descriptor1],
        [double("source2"), descriptor2]
      ])

      allow(Ephem::Segments::BaseSegment).to receive(:new)
        .and_return(segment1, segment2)

      spk = described_class.new(daf: daf)

      expect(daf).to receive(:close)
      expect(segment1).to receive(:clear_data)
      expect(segment2).to receive(:clear_data)

      spk.close
    end
  end

  describe "#to_s" do
    it "returns a formatted description of the SPK file and its segments" do
      daf = instance_double(Ephem::IO::DAF)
      segment1 = instance_double(
        Ephem::Segments::BaseSegment,
        to_s: "Segment 1",
        center: 399,
        target: 301
      )
      segment2 = instance_double(
        Ephem::Segments::BaseSegment,
        to_s: "Segment 2",
        center: 399,
        target: 302
      )

      descriptor1 = double("descriptor1")
      descriptor2 = double("descriptor2")
      allow(descriptor1).to receive(:[])
        .with(described_class::DATA_TYPE_IDENTIFIER)
        .and_return(2)
      allow(descriptor2).to receive(:[])
        .with(described_class::DATA_TYPE_IDENTIFIER)
        .and_return(2)

      allow(daf).to receive(:summaries).and_return([
        [double("source1"), descriptor1],
        [double("source2"), descriptor2]
      ])

      allow(Ephem::Segments::BaseSegment).to receive(:new)
        .and_return(segment1, segment2)

      spk = described_class.new(daf: daf)
      expected_output = <<~DESCRIPTION
        SPK file with 2 segments:
        Segment 1
        Segment 2
      DESCRIPTION

      expect(spk.to_s).to eq(expected_output)
    end
  end

  describe "#[]" do
    it "returns the segment for the given center and target" do
      daf = instance_double(Ephem::IO::DAF)
      segment = instance_double(
        Ephem::Segments::BaseSegment,
        center: 399,
        target: 301
      )

      descriptor = double("descriptor")
      allow(descriptor).to receive(:[])
        .with(described_class::DATA_TYPE_IDENTIFIER)
        .and_return(2)

      allow(daf).to receive(:summaries).and_return([
        [double("source"), descriptor]
      ])

      allow(Ephem::Segments::BaseSegment).to receive(:new)
        .and_return(segment)

      spk = described_class.new(daf: daf)

      expect(spk[399, 301]).to eq(segment)
    end

    it "raises KeyError when no segment is found for the center-target pair" do
      daf = instance_double(Ephem::IO::DAF)
      segment = instance_double(
        Ephem::Segments::BaseSegment,
        center: 399,
        target: 301
      )

      descriptor = double("descriptor")
      allow(descriptor).to receive(:[])
        .with(described_class::DATA_TYPE_IDENTIFIER)
        .and_return(2)

      allow(daf).to receive(:summaries).and_return([
        [double("source"), descriptor]
      ])

      allow(Ephem::Segments::BaseSegment).to receive(:new)
        .and_return(segment)

      spk = described_class.new(daf: daf)

      expect { spk[399, 302] }.to raise_error(
        KeyError,
        "No segment found for center: 399, target: 302"
      )
    end
  end

  describe "#comments" do
    it "delegates to the DAF comments" do
      daf = instance_double(Ephem::IO::DAF)
      allow(daf).to receive(:summaries).and_return([])
      allow(daf).to receive(:comments).and_return("Sample comment")

      spk = described_class.new(daf: daf)

      expect(spk.comments).to eq("Sample comment")
    end
  end

  describe "#each_segment" do
    it "yields each segment when a block is given" do
      daf = instance_double(Ephem::IO::DAF)
      segment1 = instance_double(
        Ephem::Segments::BaseSegment,
        center: 399,
        target: 301
      )
      segment2 = instance_double(
        Ephem::Segments::BaseSegment,
        center: 399,
        target: 302
      )

      descriptor1 = double("descriptor1")
      descriptor2 = double("descriptor2")
      allow(descriptor1).to receive(:[])
        .with(described_class::DATA_TYPE_IDENTIFIER)
        .and_return(2)
      allow(descriptor2).to receive(:[])
        .with(described_class::DATA_TYPE_IDENTIFIER)
        .and_return(2)

      allow(daf).to receive(:summaries).and_return([
        [double("source1"), descriptor1],
        [double("source2"), descriptor2]
      ])

      allow(Ephem::Segments::BaseSegment).to receive(:new)
        .and_return(segment1, segment2)

      spk = described_class.new(daf: daf)
      segments = []

      spk.each_segment { |segment| segments << segment }

      expect(segments).to eq([segment1, segment2])
    end

    it "returns an enumerator when no block is given" do
      daf = instance_double(Ephem::IO::DAF)
      allow(daf).to receive(:summaries).and_return([])

      spk = described_class.new(daf: daf)

      expect(spk.each_segment).to be_an(Enumerator)
    end
  end
end
