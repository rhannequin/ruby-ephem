# frozen_string_literal: true

require "rubygems/package"

RSpec.describe Ephem::Download do
  describe ".call" do
    context "when downloading a JPL kernel" do
      it "downloads and writes the JPL kernel file" do
        stub_http_response(successful_response("jpl-kernel-data"))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "de440.bsp")

          described_class.call(name: "de440.bsp", target: target_path)

          expect(File.binread(target_path)).to eq("jpl-kernel-data")
          expect(Dir.children(directory)).to eq(["de440.bsp"])
        end
      end

      it "creates the kernel file with the default permissions" do
        stub_http_response(successful_response("jpl-kernel-data"))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "de440.bsp")

          described_class.call(name: "de440.bsp", target: target_path)

          file_mode = File.stat(target_path).mode & 0o777
          expect(file_mode).to eq(0o666 & ~File.umask)
        end
      end

      it "requests the kernels JPL currently serves" do
        names = %w[de431t.bsp de442.bsp de442t.bsp]

        names.each do |name|
          http = stub_http_response(successful_response("jpl-kernel-data"))

          Dir.mktmpdir do |directory|
            target_path = File.join(directory, name)

            described_class.call(name: name, target: target_path)

            expect(http).to have_received(:request)
              .with(have_attributes(path: "/ftp/eph/planets/bsp/#{name}"))
          end
        end
      end
    end

    context "when Encoding.default_internal is set" do
      it "writes a directly downloaded kernel" do
        stub_http_response(successful_response("\x8Bjpl-kernel-data"))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "de440.bsp")

          with_default_internal(Encoding::UTF_8) do
            described_class.call(name: "de440.bsp", target: target_path)
          end

          expect(File.binread(target_path)).to eq("\x8Bjpl-kernel-data".b)
        end
      end

      it "writes an extracted IMCCE kernel" do
        name = "inpop19a.bsp"
        kernel_content = "\x8Bimcce-kernel-data".b
        archive = tar_gz_with(imcce_path(name) => kernel_content)
        stub_http_response(successful_response(archive))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, name)

          with_default_internal(Encoding::UTF_8) do
            described_class.call(name: name, target: target_path)
          end

          expect(File.binread(target_path)).to eq(kernel_content)
        end
      end
    end

    context "when downloading a NAIF binary PCK kernel" do
      it "downloads and writes the PCK kernel file from NAIF" do
        name = "moon_pa_de440_200625.bpc"
        naif_uri = URI.join(described_class::NAIF_PCK_BASE_URL, name)
        stub_http_response(successful_response("binary-pck-data"))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, name)

          described_class.call(name: name, target: target_path)

          expect(File.binread(target_path)).to eq("binary-pck-data")
          expect(Net::HTTP).to have_received(:start)
            .with(naif_uri.host, naif_uri.port, use_ssl: true)
        end
      end
    end

    context "when downloading an IMCCE kernel" do
      it "downloads, extracts, and writes the IMCCE kernel file" do
        name = "inpop19a.bsp"
        tar_block_size = 512
        decoy_content = "x" * (tar_block_size + 1)
        archive = tar_gz_with(
          "README.txt" => decoy_content,
          imcce_path(name) => "imcce-kernel-data"
        )
        stub_http_response(successful_response(archive))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, name)

          described_class.call(name: name, target: target_path)

          expect(File.binread(target_path)).to eq("imcce-kernel-data")
        end
      end

      it "extracts the time ephemeris kernel shipped beside the SPK" do
        name = "inpop21a_time.bsp"
        archive = tar_gz_with(
          imcce_path("inpop21a.bsp") => "planetary-kernel-data",
          imcce_path("inpop21a.bpc") => "lunar-orientation-data",
          imcce_path(name) => "time-ephemeris-data"
        )
        stub_http_response(successful_response(archive))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, name)

          described_class.call(name: name, target: target_path)

          expect(File.binread(target_path)).to eq("time-ephemeris-data")
        end
      end

      it "extracts the lunar orientation kernel shipped beside the SPK" do
        name = "inpop21a.bpc"
        archive = tar_gz_with(
          imcce_path("inpop21a.bsp") => "planetary-kernel-data",
          imcce_path(name) => "lunar-orientation-data"
        )
        stub_http_response(successful_response(archive))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, name)

          described_class.call(name: name, target: target_path)

          expect(File.binread(target_path)).to eq("lunar-orientation-data")
        end
      end

      it "writes kernels larger than one archive read chunk" do
        name = "inpop19a.bsp"
        kernel_content = "x" * (described_class::ARCHIVE_READ_CHUNK_SIZE + 1)
        archive = tar_gz_with(imcce_path(name) => kernel_content)
        stub_http_response(successful_response(archive))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, name)

          described_class.call(name: name, target: target_path)

          expect(File.binread(target_path)).to eq(kernel_content)
        end
      end

      it "raises a DownloadError when the archive lacks the kernel" do
        archive = tar_gz_with(imcce_path("inpop10b.bsp") => "other kernel")
        stub_http_response(successful_response(archive))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "inpop19a.bsp")

          expect {
            described_class.call(name: "inpop19a.bsp", target: target_path)
          }.to raise_error(
            Ephem::DownloadError,
            "inpop19a/inpop19a_TDB_m100_p100_spice.tar.gz does not contain " \
            "inpop19a_TDB_m100_p100_spice.bsp"
          )
          expect(Dir.children(directory)).to be_empty
        end
      end

      it "keeps the existing kernel when the archive lacks the kernel" do
        archive = tar_gz_with(imcce_path("inpop10b.bsp") => "other kernel")
        stub_http_response(successful_response(archive))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "inpop19a.bsp")
          File.binwrite(target_path, "existing kernel")

          expect {
            described_class.call(name: "inpop19a.bsp", target: target_path)
          }.to raise_error(Ephem::DownloadError)
          expect(File.binread(target_path)).to eq("existing kernel")
          expect(Dir.children(directory)).to eq(["inpop19a.bsp"])
        end
      end
    end

    context "when the server responds with an error" do
      it "raises a DownloadError and leaves no file behind" do
        stub_http_response(not_found_response)

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
          expect(Dir.children(directory)).to be_empty
        end
      end

      it "keeps the existing kernel" do
        stub_http_response(not_found_response)

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "inpop19a.bsp")
          File.binwrite(target_path, "existing kernel")

          expect {
            described_class.call(name: "inpop19a.bsp", target: target_path)
          }.to raise_error(Ephem::DownloadError)
          expect(File.binread(target_path)).to eq("existing kernel")
          expect(Dir.children(directory)).to eq(["inpop19a.bsp"])
        end
      end
    end

    context "when the connection fails" do
      it "wraps network errors in a DownloadError" do
        network_errors.each do |network_error|
          allow(Net::HTTP).to receive(:start).and_raise(network_error)

          Dir.mktmpdir do |directory|
            target_path = File.join(directory, "de440.bsp")

            expect {
              described_class.call(name: "de440.bsp", target: target_path)
            }.to raise_error(
              Ephem::DownloadError,
              /\AFailed to download #{Regexp.escape(jpl_url("de440.bsp"))}: /
            ) { |error| expect(error.cause).to be(network_error) }
            expect(Dir.children(directory)).to be_empty
          end
        end
      end

      it "wraps errors raised while reading the body" do
        reset_response = Net::HTTPOK.new("1.1", "200", "OK")
        allow(reset_response).to receive(:read_body)
          .and_yield("partial data".b)
          .and_raise(Errno::ECONNRESET)
        stub_http_response(reset_response)

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "de440.bsp")
          File.binwrite(target_path, "existing kernel")

          expect {
            described_class.call(name: "de440.bsp", target: target_path)
          }.to raise_error(Ephem::DownloadError) { |error|
            expect(error.cause).to be_a(Errno::ECONNRESET)
          }
          expect(File.binread(target_path)).to eq("existing kernel")
          expect(Dir.children(directory)).to eq(["de440.bsp"])
        end
      end
    end

    context "when the IMCCE archive is corrupt" do
      it "wraps a gzip error in a DownloadError" do
        stub_http_response(successful_response("not a gzip archive"))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "inpop19a.bsp")

          expect {
            described_class.call(name: "inpop19a.bsp", target: target_path)
          }.to raise_error(
            Ephem::DownloadError,
            /\Ainpop19a\/inpop19a_TDB_m100_p100_spice.tar.gz is not a valid/
          ) { |error| expect(error.cause).to be_a(Zlib::GzipFile::Error) }
          expect(Dir.children(directory)).to be_empty
        end
      end

      it "wraps an invalid tar archive in a DownloadError" do
        stub_http_response(successful_response(gzip("not a tar" * 200)))

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "inpop19a.bsp")

          expect {
            described_class.call(name: "inpop19a.bsp", target: target_path)
          }.to raise_error(Ephem::DownloadError) { |error|
            expect(error.cause).to be_a(Gem::Package::Error)
          }
          expect(Dir.children(directory)).to be_empty
        end
      end

      it "wraps a tar header parsing error in a DownloadError" do
        stub_http_response(successful_response(gzip("not a tar" * 200)))
        allow(Gem::Package::TarReader).to receive(:new)
          .and_raise(ArgumentError, '"ot a tar" is not an octal string')

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "inpop19a.bsp")

          expect {
            described_class.call(name: "inpop19a.bsp", target: target_path)
          }.to raise_error(Ephem::DownloadError, /is not an octal string/)
          expect(Dir.children(directory)).to be_empty
        end
      end
    end

    context "when the download is interrupted" do
      it "keeps the existing kernel and removes the partial file" do
        interrupted_response = Net::HTTPOK.new("1.1", "200", "OK")
        allow(interrupted_response).to receive(:read_body)
          .and_yield("partial data".b)
          .and_raise(Interrupt)
        stub_http_response(interrupted_response)

        Dir.mktmpdir do |directory|
          target_path = File.join(directory, "de440.bsp")
          File.binwrite(target_path, "existing kernel")

          expect {
            described_class.call(name: "de440.bsp", target: target_path)
          }.to raise_error(Interrupt)
          expect(File.binread(target_path)).to eq("existing kernel")
          expect(Dir.children(directory)).to eq(["de440.bsp"])
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

      it "raises an UnsupportedError for de431.bsp, which JPL removed" do
        expect {
          described_class.call(name: "de431.bsp", target: "path")
        }.to raise_error(Ephem::UnsupportedError)
      end
    end
  end

  def successful_response(body)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
      allow(response).to receive(:read_body).and_yield(body.b)
    end
  end

  def network_errors
    [
      SocketError.new("getaddrinfo: nodename nor servname provided"),
      Net::OpenTimeout.new("execution expired"),
      Net::ReadTimeout.new("Net::ReadTimeout"),
      OpenSSL::SSL::SSLError.new("certificate verify failed"),
      EOFError.new("end of file reached"),
      Errno::ECONNRESET.new,
      Errno::ECONNREFUSED.new
    ]
  end

  def jpl_url(name)
    URI.join(described_class::JPL_BASE_URL, name).to_s
  end

  def not_found_response
    Net::HTTPNotFound.new("1.1", "404", "Not Found")
  end

  def stub_http_response(response)
    http = double(request: nil)
    allow(http).to receive(:request).and_yield(response)
    allow(Net::HTTP).to receive(:start).and_yield(http)
    http
  end

  def imcce_path(name)
    described_class::IMCCE_KERNELS.fetch(name)
  end

  def with_default_internal(encoding)
    original_encoding = Encoding.default_internal
    set_default_internal(encoding)
    yield
  ensure
    set_default_internal(original_encoding)
  end

  def set_default_internal(encoding)
    original_verbose = $VERBOSE
    $VERBOSE = nil
    Encoding.default_internal = encoding
  ensure
    $VERBOSE = original_verbose
  end

  def gzip(content)
    archive = StringIO.new
    Zlib::GzipWriter.wrap(archive) { |gz| gz.write(content) }
    archive.string
  end

  def tar_gz_with(entries)
    archive = StringIO.new
    Zlib::GzipWriter.wrap(archive) do |gz|
      Gem::Package::TarWriter.new(gz) do |tar|
        entries.each do |archive_path, content|
          tar.add_file_simple(archive_path, 0o644, content.bytesize) do |out|
            out.write(content)
          end
        end
      end
    end
    archive.string
  end
end
