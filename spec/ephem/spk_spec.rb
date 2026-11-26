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

  describe "querying a time outside a kernel" do
    it "explains which pair does not cover which time" do
      spk = described_class.open(de421_2000_excerpt)
      segment = spk[0, 3]

      expect { segment.position_at(2400000.5) }.to raise_error(
        Ephem::OutOfRangeError,
        "JD 2400000.5 (1858-11-17) is outside the coverage of " \
        "Solar System Barycenter (0) -> Earth-Moon Barycenter (3), " \
        "which covers JD 2451536.5..2451920.5 (1999-12-24..2001-01-11)"
      )

      spk.close
    end

    it "reports times just past the end of the coverage" do
      spk = described_class.open(de421_2000_excerpt)
      segment = spk[0, 3]
      past_end = segment.end_jd + 1e-6

      expect { segment.state_at([segment.end_jd, past_end]) }
        .to raise_error(Ephem::OutOfRangeError) do |error|
          expect(error.out_of_range_times).to eq([past_end])
        end

      spk.close
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

  describe "#position_at" do
    it "reads a stored pair directly" do
      with_test_spk do |spk|
        position = spk.position_at(target: 3, center: 0, tdb: test_time)

        expect(position).to eq(spk[0, 3].compute(test_time))
      end
    end

    it "adds pairs chained from the center down to the target" do
      with_test_spk do |spk|
        position = spk.position_at(target: 399, center: 0, tdb: test_time)

        expected = spk[0, 3].compute(test_time) +
          spk[3, 399].compute(test_time)
        expect(position).to eq(expected)
      end
    end

    it "subtracts pairs walked from their target up to their center" do
      with_test_spk do |spk|
        position = spk.position_at(target: 301, center: 399, tdb: test_time)

        expected = spk[3, 301].compute(test_time) -
          spk[3, 399].compute(test_time)
        expect(position).to eq(expected)
      end
    end

    it "negates the chain when every pair is walked backward" do
      with_test_spk do |spk|
        position = spk.position_at(target: 0, center: 399, tdb: test_time)

        expected = spk[0, 3].compute(test_time) +
          spk[3, 399].compute(test_time)
        expect_close_vectors(position, negated(expected))
      end
    end

    it "chains through a common ancestor of both bodies" do
      with_test_spk do |spk|
        position = spk.position_at(target: 199, center: 299, tdb: test_time)

        expected = spk[0, 1].compute(test_time) +
          spk[1, 199].compute(test_time) -
          spk[0, 2].compute(test_time) -
          spk[2, 299].compute(test_time)
        expect_close_vectors(position, expected)
      end
    end

    it "returns a zero vector for a body relative to itself" do
      with_test_spk do |spk|
        position = spk.position_at(target: 399, center: 399, tdb: test_time)

        expect(position).to eq(Ephem::Core::Vector.new(0.0, 0.0, 0.0))
      end
    end

    it "returns one position per time for an array of times" do
      with_test_spk do |spk|
        times = [test_time, test_time + 1.5]

        positions = spk.position_at(target: 301, center: 399, tdb: times)

        expected = times.map do |time|
          spk[3, 301].compute(time) - spk[3, 399].compute(time)
        end
        expect(positions).to eq(expected)
      end
    end

    it "passes the fractional part of the date to every pair" do
      with_test_spk do |spk|
        position = spk.position_at(
          target: 301, center: 399, tdb: test_time, tdb2: 0.25
        )

        expected = spk[3, 301].compute(test_time, 0.25) -
          spk[3, 399].compute(test_time, 0.25)
        expect(position).to eq(expected)
      end
    end

    it "raises KeyError when no chain links the two bodies" do
      with_test_spk do |spk|
        expect { spk.position_at(target: 999, center: 0, tdb: test_time) }
          .to raise_error(
            KeyError,
            "No chain of segments links center: 0, target: 999"
          )
      end
    end

    it "raises KeyError for an unknown body relative to itself" do
      with_test_spk do |spk|
        expect { spk.position_at(target: 999, center: 999, tdb: test_time) }
          .to raise_error(KeyError)
      end
    end

    it "raises OutOfRangeError when a pair does not cover the time" do
      with_test_spk do |spk|
        expect { spk.position_at(target: 301, center: 399, tdb: 0.0) }
          .to raise_error(Ephem::OutOfRangeError)
      end
    end
  end

  describe "#state_at" do
    it "reads a stored pair directly" do
      with_test_spk do |spk|
        state = spk.state_at(target: 399, center: 3, tdb: test_time)

        expected = spk[3, 399].compute_and_differentiate(test_time)
        expect(state.to_arrays).to eq(expected.to_arrays)
      end
    end

    it "combines positions and velocities along the chain" do
      with_test_spk do |spk|
        state = spk.state_at(target: 301, center: 399, tdb: test_time)

        moon = spk[3, 301].compute_and_differentiate(test_time)
        earth = spk[3, 399].compute_and_differentiate(test_time)
        expect(state.position).to eq(moon.position - earth.position)
        expect(state.velocity).to eq(moon.velocity - earth.velocity)
      end
    end

    it "negates positions and velocities walked backward" do
      with_test_spk do |spk|
        state = spk.state_at(target: 3, center: 399, tdb: test_time)

        earth = spk[3, 399].compute_and_differentiate(test_time)
        expect_close_vectors(state.position, negated(earth.position))
        expect_close_vectors(state.velocity, negated(earth.velocity))
      end
    end

    it "returns a zero state for a body relative to itself" do
      with_test_spk do |spk|
        state = spk.state_at(target: 3, center: 3, tdb: test_time)

        zero = Ephem::Core::Vector.new(0.0, 0.0, 0.0)
        expect(state.position).to eq(zero)
        expect(state.velocity).to eq(zero)
      end
    end

    it "returns one zero state per time for a body relative to itself" do
      with_test_spk do |spk|
        states = spk.state_at(
          target: 3, center: 3, tdb: [test_time, test_time + 1]
        )

        expect(states.size).to eq(2)
        expect(states).to all(be_a(Ephem::Core::State))
      end
    end

    it "returns one state per time for an array of times" do
      with_test_spk do |spk|
        times = [test_time, test_time + 1.5]

        states = spk.state_at(target: 399, center: 0, tdb: times, tdb2: 0.5)

        expected = times.map do |time|
          barycenter = spk[0, 3].compute_and_differentiate(time, 0.5)
          earth = spk[3, 399].compute_and_differentiate(time, 0.5)
          [
            barycenter.position + earth.position,
            barycenter.velocity + earth.velocity
          ]
        end
        actual = states.map { |state| [state.position, state.velocity] }
        expect(actual).to eq(expected)
      end
    end

    it "raises KeyError when no chain links the two bodies" do
      with_test_spk do |spk|
        expect { spk.state_at(target: 0, center: 999, tdb: test_time) }
          .to raise_error(KeyError, /center: 999, target: 0/)
      end
    end
  end

  def with_test_spk
    spk = described_class.open(test_spk)
    yield spk
  ensure
    spk&.close
  end

  def test_time
    2460676.5
  end

  def negated(vector)
    Ephem::Core::Vector.new(-vector.x, -vector.y, -vector.z)
  end

  def expect_close_vectors(actual, expected)
    actual.to_a.zip(expected.to_a).each do |actual_value, expected_value|
      expect(actual_value).to be_within(1e-6).of(expected_value)
    end
  end
end
