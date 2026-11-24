# frozen_string_literal: true

require "rubygems/package"

RSpec.describe Ephem::Download do
  describe ".call" do
    context "when downloading a JPL kernel" do
      it "downloads and writes the JPL kernel file" do
        name = "de440.bsp"
        target_path = "tmp/kernel.bsp"
        mock_content = "large-binary-data"
        file_io = StringIO.new
        pathname_double = instance_double(Pathname, dirname: "tmp")
        http_response = Net::HTTPOK.new("1.1", "200", "OK")
        allow(Pathname).to receive(:new)
          .with(target_path)
          .and_return(pathname_double)
        allow(pathname_double).to receive(:open)
          .with("wb")
          .and_yield(file_io)
          .once
        allow(Net::HTTP).to receive(:start)
          .with(anything, anything, use_ssl: true)
          .and_yield(
            double(request: nil).tap do |http|
              allow(http).to receive(:request).and_yield(http_response)
            end
          )
        allow(http_response).to receive(:read_body).and_yield(mock_content)

        described_class.call(name: name, target: target_path)

        expect(file_io.string).to eq(mock_content)
      end
    end

    context "when downloading a NAIF binary PCK kernel" do
      it "downloads and writes the PCK kernel file from NAIF" do
        name = "moon_pa_de440_200625.bpc"
        target_path = "tmp/kernel.bpc"
        mock_content = "binary-pck-data"
        file_io = StringIO.new
        pathname_double = instance_double(Pathname, dirname: "tmp")
        http_response = Net::HTTPOK.new("1.1", "200", "OK")
        allow(Pathname).to receive(:new)
          .with(target_path)
          .and_return(pathname_double)
        allow(pathname_double).to receive(:open)
          .with("wb")
          .and_yield(file_io)
          .once
        naif_uri = URI.join(described_class::NAIF_PCK_BASE_URL, name)
        allow(Net::HTTP).to receive(:start)
          .with(naif_uri.host, naif_uri.port, use_ssl: true)
          .and_yield(
            double(request: nil).tap do |http|
              allow(http).to receive(:request).and_yield(http_response)
            end
          )
        allow(http_response).to receive(:read_body).and_yield(mock_content)

        described_class.call(name: name, target: target_path)

        expect(file_io.string).to eq(mock_content)
      end
    end

    context "when downloading an IMCCE kernel" do
      it "downloads, extracts, and writes the IMCCE kernel file" do
        name = "inpop19a.bsp"
        target_path = "tmp/kernel.bsp"
        mock_content = "large-binary-data"
        file_io = StringIO.new
        pathname_double = instance_double(Pathname, dirname: "tmp")
        http_response = Net::HTTPOK.new("1.1", "200", "OK")
        tar_block_size = 512
        decoy_content = "x" * (tar_block_size + 1)
        tar_gz_file = create_temp_tar_gz_with(
          "README.txt" => decoy_content,
          described_class::IMCCE_KERNELS[name] => mock_content
        )
        tar_gz_file.rewind
        tar_gz_content = tar_gz_file.read
        allow(Pathname).to receive(:new)
          .with(target_path)
          .and_return(pathname_double)
        allow(pathname_double).to receive(:open)
          .with("wb")
          .and_yield(file_io)
          .once
        allow(Tempfile).to receive(:create)
          .with(%w[archive .tar.gz])
          .and_yield(tar_gz_file)
        allow(Net::HTTP).to receive(:start)
          .with(anything, anything, use_ssl: true)
          .and_yield(
            double(request: nil).tap do |http|
              allow(http).to receive(:request).and_yield(http_response)
            end
          )
        allow(http_response).to receive(:read_body).and_yield(tar_gz_content)

        described_class.call(name: name, target: target_path)

        expect(file_io.string).to eq(mock_content)
      end

      it "writes kernels larger than one archive read chunk" do
        name = "inpop19a.bsp"
        kernel_content = "x" * (described_class::ARCHIVE_READ_CHUNK_SIZE + 1)
        archive = create_temp_tar_gz_with(
          described_class::IMCCE_KERNELS[name] => kernel_content
        )
        stub_http_response(successful_response(archive.read))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, name)

          described_class.call(name: name, target: target_path)

          expect(File.binread(target_path)).to eq(kernel_content)
        end
      end

      it "raises a DownloadError when the archive lacks the kernel" do
        archive = create_temp_tar_gz_with(
          described_class::IMCCE_KERNELS["inpop10b.bsp"] => "other kernel"
        )
        stub_http_response(successful_response(archive.read))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "inpop19a.bsp")

          expect {
            described_class.call(name: "inpop19a.bsp", target: target_path)
          }.to raise_error(
            Ephem::DownloadError,
            "inpop19a/inpop19a_TDB_m100_p100_spice.tar.gz does not contain " \
            "inpop19a_TDB_m100_p100_spice.bsp"
          )
          expect(File).not_to exist(target_path)
        end
      end
    end

    context "when the server responds with an error" do
      it "raises a DownloadError and leaves no file behind" do
        not_found = Net::HTTPNotFound.new("1.1", "404", "Not Found")
        stub_http_response(not_found)

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "de440.bsp")

          expect {
            described_class.call(name: "de440.bsp", target: target_path)
          }.to raise_error(
            Ephem::DownloadError,
            "Failed to download " \
            "https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/de440.bsp: " \
            "404 Not Found"
          )
          expect(File).not_to exist(target_path)
        end
      end
    end

    context "when the kernel is not supported" do
      it "raises an UnsupportedError" do
        expect {
          described_class.call(name: "unsupported", target: "path")
        }.to raise_error(
          Ephem::UnsupportedError,
          "Kernel unsupported is not supported by the library at the moment."
        )
      end
    end
  end

  def successful_response(body)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      allow(response).to receive(:read_body).and_yield(body)
    end
  end

  def stub_http_response(response)
    http = double(request: nil)
    allow(http).to receive(:request).and_yield(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
  end

  def create_temp_tar_gz_with(entries)
    Tempfile.new.tap do |tempfile|
      Zlib::GzipWriter.open(tempfile) do |gz|
        Gem::Package::TarWriter.new(gz) do |tar|
          entries.each do |archive_path, content|
            tar.add_file_simple(archive_path, 0o644, content.bytesize) do |out|
              out.write(content)
            end
          end
        end
      end
      tempfile.rewind
    end
  end
end
