# frozen_string_literal: true

RSpec.describe Ephem::Download do
  describe ".call" do
    context "when downloading a JPL kernel" do
      it "downloads and writes the JPL kernel file" do
        name = "de440.bsp"
        target_path = "tmp/kernel.bsp"
        mock_content = "large-binary-data"
        allow(Net::HTTP).to receive(:get).and_return(mock_content)
        allow(File).to receive(:write)

        described_class.call(name: name, target: target_path)

        expect(File).to have_received(:write).with(target_path, mock_content)
      end
    end

    context "when downloading an IMCCE kernel" do
      it "downloads, extracts, and writes the IMCCE kernel file" do
        name = "inpop19a.bsp"
        target_path = "tmp/kernel.bsp"
        mock_content = "large-binary-data"
        tar_gz_file = create_temp_tar_gz_with(name => mock_content)
        allow(Net::HTTP).to receive(:get).and_return(tar_gz_file.read)
        allow(File).to receive(:write)

        described_class.call(name: name, target: target_path)

        expect(File).to have_received(:write).with(target_path, mock_content)
      end
    end

    context "when the kernel is not supported" do
      it "raises an UnsupportedError" do
        expect { described_class.call(name: "unsupported", target: "path") }.to(
          raise_error(
            Ephem::UnsupportedError,
            "Kernel unsupported is not supported by the library at the moment."
          )
        )
      end
    end
  end

  def create_temp_tar_gz_with(files)
    Tempfile.new.tap do |tempfile|
      Zlib::GzipWriter.open(tempfile) do |gz|
        Minitar::Writer.open(gz) do |tar|
          files.each do |filename, content|
            io = StringIO.new(content)
            tar.add_file_simple(
              described_class::IMCCE_KERNELS[filename],
              size: content.bytesize,
              mode: 0o644,
              mtime: Time.now.to_i
            ) do |out|
              IO.copy_stream(io, out)
            end
          end
        end
      end
      tempfile.rewind
    end
  end
end
