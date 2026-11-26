# frozen_string_literal: true

require "tmpdir"

RSpec.describe Ephem::SPK do
  include TestSpkHelper

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
      allow(daf_double).to receive(:file_type)
        .and_return(:spk)

      spk = described_class.open("spk_file.bsp")

      expect(spk).to be_an_instance_of(described_class)
    end

    it "rejects a binary PCK file" do
      expect { described_class.open(moon_pa_de440_excerpt) }.to raise_error(
        Ephem::FileFormatError, /binary PCK file, use Ephem::PCK/
      )
    end

    it "lets a permission error through unchanged" do
      allow(File).to receive(:open)
        .and_raise(Errno::EACCES, "spk_file.bsp")

      expect { described_class.open("spk_file.bsp") }
        .to raise_error(Errno::EACCES)
    end

    it "yields the kernel to the block" do
      yielded_kernel = nil

      described_class.open(de421_2000_excerpt) do |spk|
        yielded_kernel = spk
      end

      expect(yielded_kernel).to be_an_instance_of(described_class)
    end

    it "returns the block's value" do
      result = described_class.open(de421_2000_excerpt) { :block_value }

      expect(result).to eq(:block_value)
    end

    it "closes the file after the block returns" do
      opened_files = track_opened_files

      described_class.open(de421_2000_excerpt) { |spk| spk.comments }

      expect(opened_files).to contain_exactly(be_closed)
    end

    it "closes the file when the block raises" do
      opened_files = track_opened_files

      expect do
        described_class.open(de421_2000_excerpt) { raise "boom" }
      end.to raise_error(RuntimeError, "boom")
      expect(opened_files).to contain_exactly(be_closed)
    end

    it "leaves the file open without a block" do
      opened_files = track_opened_files

      spk = described_class.open(de421_2000_excerpt)
      closed_states = opened_files.map(&:closed?)
      spk.close

      expect(closed_states).to eq([false])
    end

    it "allows the block to close the kernel itself" do
      expect do
        described_class.open(de421_2000_excerpt) { |spk| spk.close }
      end.not_to raise_error
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

  describe "#type" do
    context "when record data has INPOP-like filename" do
      it "returns the INPOP identifier" do
        spk = described_class.open(inpop21a_2000_excerpt)

        type = spk.type

        expect(type).to eq described_class::INPOP
      end
    end

    context "when record data has DE-like filename" do
      it "returns the JPL DE identifier" do
        spk = described_class.open(de421_2000_excerpt)

        type = spk.type

        expect(type).to eq described_class::JPL_DE
      end
    end

    context "when the first segment has a DE-like source" do
      it "returns the JPL DE identifier" do
        spk = described_class.open(de405_2000_excerpt)

        type = spk.type

        expect(type).to eq described_class::JPL_DE
      end
    end

    context "when there is no information available" do
      it "returns nil" do
      end
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

    it "finds a segment with a negative target ID" do
      Dir.mktmpdir("ephem_test_") do |temp_dir|
        original_spk = described_class.open(de421_2000_excerpt)
        patched_spk = described_class.open(
          de421_2000_excerpt_with_first_target(-82, directory: temp_dir)
        )
        test_time = 2451545.0

        patched_segment = patched_spk[0, -82]

        original_state = original_spk[0, 1].compute_and_differentiate(test_time)
        patched_state = patched_segment.compute_and_differentiate(test_time)
        expect(patched_segment.target).to eq(-82)
        expect(patched_state.position.to_a).to eq original_state.position.to_a
        expect(patched_state.velocity.to_a).to eq original_state.velocity.to_a

        original_spk.close
        patched_spk.close
      end
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

  def track_opened_files
    opened_files = []
    allow(File).to receive(:open).and_wrap_original do |original, *arguments|
      original.call(*arguments).tap { |file| opened_files << file }
    end
    opened_files
  end
end
