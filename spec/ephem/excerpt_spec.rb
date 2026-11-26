# frozen_string_literal: true

require "fileutils"
require "tmpdir"

RSpec.describe Ephem::Excerpt do
  include TestSpkHelper

  describe "#extract" do
    it "includes only the specified target segments" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )

      expect(excerpt_spk.segments.size).to eq target_ids.size
      segment_targets = excerpt_spk.segments.map(&:target)
      target_ids.each do |target_id|
        expect(segment_targets).to include(target_id)
      end

      original_spk.close
      excerpt_spk.close
    end

    it "produces a smaller file than the original" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )

      original_size = File.size(original_spk_path)
      excerpt_size = File.size(excerpt_path)
      expect(excerpt_size).to be < original_size

      original_spk.close
      excerpt_spk.close
    end

    it "produces identical computation results using SPK#excerpt" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      test_time = 2459000.0
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]
      original_state = original_segment.state_at(test_time)
      excerpt_state = excerpt_segment.state_at(test_time)

      expect(excerpt_state.position.to_a).to eq original_state.position.to_a
      expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a

      original_spk.close
      excerpt_spk.close
    end

    it "produces identical computation results using Excerpt directly" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      test_time = 2459000.0
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = Ephem::Excerpt.new(original_spk).extract(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]
      original_state = original_segment.compute_and_differentiate(test_time)
      excerpt_state = excerpt_segment.compute_and_differentiate(test_time)

      expect(excerpt_state.position.to_a).to eq original_state.position.to_a
      expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a

      original_spk.close
      excerpt_spk.close
    end

    it "handles a short time span correctly" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2459000.0
      end_jd = 2459001.0
      target_ids = [3, 10, 301, 399]
      test_time = 2459000.5
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]
      original_state = original_segment.compute_and_differentiate(test_time)
      excerpt_state = excerpt_segment.compute_and_differentiate(test_time)

      expect(excerpt_state.position.to_a).to eq original_state.position.to_a
      expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a

      original_spk.close
      excerpt_spk.close
    end

    it "works with a single target ID" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3]
      test_time = 2459000.0
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )

      expect(excerpt_spk.segments.size).to eq 1
      expect(excerpt_spk.segments.first.target).to eq target_ids.first
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]
      original_state = original_segment.compute_and_differentiate(test_time)
      excerpt_state = excerpt_segment.compute_and_differentiate(test_time)
      expect(excerpt_state.position.to_a).to eq original_state.position.to_a
      expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a

      original_spk.close
      excerpt_spk.close
    end

    it "raises an error for time outside excerpt range but works in original" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      outside_time = 2460000.0
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]

      expect {
        excerpt_segment.compute_and_differentiate(outside_time)
      }.to raise_error(Ephem::OutOfRangeError)
      expect {
        original_segment.compute_and_differentiate(outside_time)
      }.not_to raise_error

      original_spk.close
      excerpt_spk.close
    end

    it "produces correct results for multiple test times" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")
      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      test_times = [
        2458849.5,
        2459000.0,
        2459215.0,
        2459580.5
      ]
      center = 0
      target = 3
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )
      original_segment = original_spk[center, target]
      excerpt_segment = excerpt_spk[center, target]

      test_times.each do |time|
        original_state = original_segment.compute_and_differentiate(time)
        excerpt_state = excerpt_segment.compute_and_differentiate(time)
        expect(excerpt_state.position.to_a).to eq original_state.position.to_a
        expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a
      end

      original_spk.close
      excerpt_spk.close
    end

    it "produces correct results for multiple center-target pairs" do
      temp_dir = Dir.mktmpdir("ephem_test_")
      original_spk_path = test_spk
      excerpt_path = File.join(temp_dir, "excerpt.bsp")

      start_jd = 2458849.5
      end_jd = 2459580.5
      target_ids = [3, 10, 301, 399]
      test_time = 2459000.0
      test_pairs = [
        [0, 3],
        [0, 10],
        [3, 301],
        [3, 399]
      ]
      original_spk = Ephem::SPK.open(original_spk_path)
      excerpt_spk = original_spk.excerpt(
        output_path: excerpt_path,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids
      )

      test_pairs.each do |center, target|
        original_segment = original_spk[center, target]
        excerpt_segment = excerpt_spk[center, target]
        original_state = original_segment.compute_and_differentiate(test_time)
        excerpt_state = excerpt_segment.compute_and_differentiate(test_time)
        expect(excerpt_state.position.to_a).to eq original_state.position.to_a
        expect(excerpt_state.velocity.to_a).to eq original_state.velocity.to_a
      end

      original_spk.close
      excerpt_spk.close
    end

    it "keeps segments with a negative target ID" do
      Dir.mktmpdir("ephem_test_") do |temp_dir|
        original_spk = Ephem::SPK.open(
          de421_2000_excerpt_with_first_target(-82, directory: temp_dir)
        )
        excerpt_spk = original_spk.excerpt(
          output_path: File.join(temp_dir, "excerpt.bsp"),
          start_jd: 2451545.0,
          end_jd: 2451555.0,
          target_ids: [-82]
        )

        expect(excerpt_spk.segments.map(&:target)).to eq [-82]
        expect(excerpt_spk.segments.map(&:center)).to eq [0]

        original_spk.close
        excerpt_spk.close
      end
    end

    it "raises errors raised while extracting a segment" do
      spk = Ephem::SPK.open(test_spk)
      allow(spk.daf).to receive(:read_array)
        .and_raise(Ephem::FileFormatError, "corrupted array")

      Dir.mktmpdir("ephem_test_") do |temp_dir|
        excerpt_path = File.join(temp_dir, "excerpt.bsp")

        expect { extract_year_2020(spk, excerpt_path) }
          .to raise_error(Ephem::FileFormatError, "corrupted array")
      end

      spk.close
    end

    it "does not print anything when extraction fails" do
      spk = Ephem::SPK.open(test_spk)
      allow(spk.daf).to receive(:read_array)
        .and_raise(Ephem::FileFormatError, "corrupted array")

      Dir.mktmpdir("ephem_test_") do |temp_dir|
        excerpt_path = File.join(temp_dir, "excerpt.bsp")

        expect { extract_ignoring_errors(spk, excerpt_path) }
          .not_to output.to_stdout
      end

      spk.close
    end

    it "closes and removes the partial file when extraction fails" do
      spk = Ephem::SPK.open(test_spk)
      allow(spk.daf).to receive(:read_array)
        .and_raise(Ephem::FileFormatError, "corrupted array")

      Dir.mktmpdir("ephem_test_") do |temp_dir|
        excerpt_path = File.join(temp_dir, "excerpt.bsp")
        output_files = record_temp_files

        expect { extract_year_2020(spk, excerpt_path) }
          .to raise_error(Ephem::FileFormatError)
        expect(output_files.size).to eq 1
        expect(output_files.first).to be_closed
        expect(Dir.children(temp_dir)).to be_empty
      end

      spk.close
    end

    it "keeps an existing output file when extraction fails" do
      spk = Ephem::SPK.open(test_spk)
      allow(spk.daf).to receive(:read_array)
        .and_raise(Ephem::FileFormatError, "corrupted array")

      Dir.mktmpdir("ephem_test_") do |temp_dir|
        excerpt_path = File.join(temp_dir, "excerpt.bsp")
        File.write(excerpt_path, "previous excerpt")

        expect { extract_year_2020(spk, excerpt_path) }
          .to raise_error(Ephem::FileFormatError)
        expect(File.read(excerpt_path)).to eq "previous excerpt"
      end

      spk.close
    end

    it "can write the excerpt over its own source kernel" do
      Dir.mktmpdir("ephem_test_") do |temp_dir|
        kernel_path = File.join(temp_dir, "kernel.bsp")
        FileUtils.cp(test_spk, kernel_path)
        spk = Ephem::SPK.open(kernel_path)

        excerpt_spk = extract_year_2020(spk, kernel_path)

        expect(excerpt_spk.segments.size).to eq spk.segments.size
        expect(File.size(kernel_path)).to be < File.size(test_spk)

        spk.close
        excerpt_spk.close
      end
    end

    it "raises UnsupportedError for an unsupported SPK data type" do
      spk = Ephem::SPK.open(test_spk)
      stub_data_type(spk, data_type_index: 5, data_type: 9)

      Dir.mktmpdir("ephem_test_") do |temp_dir|
        excerpt_path = File.join(temp_dir, "excerpt.bsp")

        expect { extract_year_2020(spk, excerpt_path) }.to raise_error(
          Ephem::UnsupportedError, /SPK segment .* data type 9/
        )
        expect(File.exist?(excerpt_path)).to be false
      end

      spk.close
    end

    it "raises UnsupportedError for an unsupported PCK data type" do
      pck = Ephem::PCK.open(moon_pa_de440_excerpt)
      stub_data_type(pck, data_type_index: 4, data_type: 3)

      Dir.mktmpdir("ephem_test_") do |temp_dir|
        excerpt_path = File.join(temp_dir, "excerpt.bpc")

        expect { extract_year_2020(pck, excerpt_path) }.to raise_error(
          Ephem::UnsupportedError, /PCK segment .* data type 3/
        )
        expect(File.exist?(excerpt_path)).to be false
      end

      pck.close
    end

    it "excerpts a binary PCK" do
      pck = Ephem::PCK.open(moon_pa_de440_excerpt)

      Dir.mktmpdir("ephem_test_") do |temp_dir|
        excerpt_path = File.join(temp_dir, "excerpt.bpc")
        excerpt_pck = extract_year_2020(pck, excerpt_path)

        expect(excerpt_pck).to be_a(Ephem::PCK)
        expect(excerpt_pck[31008].body).to eq 31008

        excerpt_pck.close
      end

      pck.close
    end
  end

  describe Ephem::Excerpt::DAFWriter do
    describe "#write_file_record" do
      it "packs little-endian record pointers as little-endian integers" do
        file = StringIO.new("\0".b * Ephem::Excerpt::RECORD_SIZE)
        writer = build_writer(file, endianness: :little)

        writer.write_file_record

        expect(file.string.byteslice(76, 12)).to eq(
          "\x04\x00\x00\x00\x04\x00\x00\x00\x01\x02\x00\x00".b
        )
      end

      it "packs big-endian record pointers as big-endian integers" do
        file = StringIO.new("\0".b * Ephem::Excerpt::RECORD_SIZE)
        writer = build_writer(file, endianness: :big)

        writer.write_file_record

        expect(file.string.byteslice(76, 12)).to eq(
          "\x00\x00\x00\x04\x00\x00\x00\x04\x00\x00\x02\x01".b
        )
      end
    end

    describe "#setup_formats" do
      it "packs little-endian summary integers as little-endian" do
        writer = Ephem::Excerpt::DAFWriter.new(StringIO.new)
        writer.endianness = :little
        writer.setup_formats(2, 6)

        packed = [0.0, 0.0, 3, 0, 1, 2, 641, 1024]
          .pack(writer.summary_format)

        expect(packed.byteslice(16, 4)).to eq "\x03\x00\x00\x00".b
        expect(packed.byteslice(36, 4)).to eq "\x00\x04\x00\x00".b
      end

      it "packs negative summary integers as signed" do
        writer = Ephem::Excerpt::DAFWriter.new(StringIO.new)
        writer.endianness = :big
        writer.setup_formats(2, 6)

        packed = [0.0, 0.0, -31, 0, 1, 2, 641, 1024]
          .pack(writer.summary_format)

        expect(packed.byteslice(16, 4).unpack1("l>")).to eq(-31)
      end
    end
  end

  def extract_year_2020(kernel, output_path)
    Ephem::Excerpt.new(kernel).extract(
      output_path: output_path,
      start_jd: 2458849.5,
      end_jd: 2459215.5
    )
  end

  def extract_ignoring_errors(kernel, output_path)
    extract_year_2020(kernel, output_path)
  rescue Ephem::Error
    nil
  end

  def stub_data_type(kernel, data_type_index:, data_type:)
    summaries = kernel.daf.summaries.map do |name, values|
      altered_values = values.dup
      altered_values[data_type_index] = data_type
      [name, altered_values]
    end
    allow(kernel.daf).to receive(:summaries).and_return(summaries)
  end

  def record_temp_files
    temp_files = []
    allow(File).to receive(:open).and_wrap_original do |original, *args|
      file = original.call(*args)
      temp_files << file if args.first.to_s.end_with?(".tmp")
      file
    end
    temp_files
  end

  def build_writer(file, endianness:)
    writer = Ephem::Excerpt::DAFWriter.new(file)
    writer.endianness = endianness
    writer.forward_record = 4
    writer.backward_record = 4
    writer.free = 513
    writer
  end
end
