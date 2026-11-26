# frozen_string_literal: true

require "net/http"
require "pathname"
require "tempfile"
require "zlib"
require "fileutils"

module Ephem
  class Download
    JPL_BASE_URL = "https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/"
    IMCCE_BASE_URL = "https://ftp.imcce.fr/pub/ephem/planets/"
    NAIF_PCK_BASE_URL =
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/"
    ARCHIVE_READ_CHUNK_SIZE = 1024 * 1024

    JPL_KERNELS = %w[
      de102.bsp
      de200.bsp
      de202.bsp
      de403.bsp
      de405.bsp
      de405_1960_2020.bsp
      de406.bsp
      de410.bsp
      de413.bsp
      de414.bsp
      de418.bsp
      de421.bsp
      de422.bsp
      de422_1850_2050.bsp
      de423.bsp
      de424.bsp
      de424s.bsp
      de425.bsp
      de430_1850-2150.bsp
      de430_plus_MarsPC.bsp
      de430t.bsp
      de431t.bsp
      de432t.bsp
      de433.bsp
      de433_plus_MarsPC.bsp
      de433t.bsp
      de434.bsp
      de434s.bsp
      de434t.bsp
      de435.bsp
      de435s.bsp
      de435t.bsp
      de436.bsp
      de436s.bsp
      de436t.bsp
      de438.bsp
      de438_plus_MarsPC.bsp
      de438s.bsp
      de438t.bsp
      de440.bsp
      de440s.bsp
      de440s_plus_MarsPC.bsp
      de440t.bsp
      de441.bsp
      de442.bsp
      de442t.bsp
    ].freeze

    NAIF_PCK_KERNELS = %w[
      moon_pa_de421_1900-2050.bpc
      moon_pa_de440_200625.bpc
    ].freeze

    IMCCE_KERNELS = {
      "inpop10b.bsp" => "inpop10b_TDB_m100_p100_spice.bsp",
      "inpop10b.bpc" => "inpop10b_TDB_m100_p100_spice.bpc",
      "inpop10b_large.bsp" => "inpop10b_TDB_m1000_p1000_spice.bsp",
      "inpop10b_large.bpc" => "inpop10b_TDB_m1000_p1000_spice.bpc",
      "inpop10e.bsp" => "inpop10e_TDB_m100_p100_spice.bsp",
      "inpop10e.bpc" => "inpop10e_TDB_m100_p100_spice.bpc",
      "inpop10e_large.bsp" => "inpop10e_TDB_m1000_p1000_spice.bsp",
      "inpop10e_large.bpc" => "inpop10e_TDB_m1000_p1000_spice.bpc",
      "inpop13c.bsp" => "inpop13c_TDB_m100_p100_spice.bsp",
      "inpop13c.bpc" => "inpop13c_TDB_m100_p100_spice.bpc",
      "inpop13c_time.bsp" => "inpop13c_TDB_m100_p100_spice_time.bsp",
      "inpop13c_large.bsp" => "inpop13c_TDB_m1000_p1000_spice.bsp",
      "inpop13c_large.bpc" => "inpop13c_TDB_m1000_p1000_spice.bpc",
      "inpop13c_large_time.bsp" => "inpop13c_TDB_m1000_p1000_spice_time.bsp",
      "inpop17a.bsp" => "inpop17a_TDB_m100_p100_spice.bsp",
      "inpop17a.bpc" => "inpop17a_TDB_m100_p100_spice.bpc",
      "inpop17a_time.bsp" => "inpop17a_TDB_m100_p100_spice_time.bsp",
      "inpop17a_large.bsp" => "inpop17a_TDB_m1000_p1000_spice.bsp",
      "inpop17a_large.bpc" => "inpop17a_TDB_m1000_p1000_spice.bpc",
      "inpop17a_large_time.bsp" => "inpop17a_TDB_m1000_p1000_spice_time.bsp",
      "inpop19a.bsp" => "inpop19a_TDB_m100_p100_spice.bsp",
      "inpop19a.bpc" => "inpop19a_TDB_m100_p100_spice.bpc",
      "inpop19a_time.bsp" => "inpop19a_TDB_m100_p100_spice_time.bsp",
      "inpop19a_large.bsp" => "inpop19a_TDB_m1000_p1000_spice.bsp",
      "inpop19a_large.bpc" => "inpop19a_TDB_m1000_p1000_spice.bpc",
      "inpop19a_large_time.bsp" => "inpop19a_TDB_m1000_p1000_spice_time.bsp",
      "inpop21a.bsp" => "inpop21a_TDB_m100_p100_spice.bsp",
      "inpop21a.bpc" => "inpop21a_TDB_m100_p100_spice.bpc",
      "inpop21a_time.bsp" => "inpop21a_TDB_m100_p100_spice_time.bsp",
      "inpop21a_large.bsp" => "inpop21a_TDB_m1000_p1000_spice.bsp",
      "inpop21a_large.bpc" => "inpop21a_TDB_m1000_p1000_spice.bpc",
      "inpop21a_large_time.bsp" => "inpop21a_TDB_m1000_p1000_spice_time.bsp"
    }.freeze

    IMCCE_KERNELS_MATCHING = {
      "inpop10b.bsp" => "inpop10b/inpop10b_TDB_m100_p100_spice.tar.gz",
      "inpop10b.bpc" => "inpop10b/inpop10b_TDB_m100_p100_spice.tar.gz",
      "inpop10b_large.bsp" => "inpop10b/inpop10b_TDB_m1000_p1000_spice.tar.gz",
      "inpop10b_large.bpc" => "inpop10b/inpop10b_TDB_m1000_p1000_spice.tar.gz",
      "inpop10e.bsp" => "inpop10e/inpop10e_TDB_m100_p100_spice_release2.tar.gz",
      "inpop10e.bpc" => "inpop10e/inpop10e_TDB_m100_p100_spice_release2.tar.gz",
      "inpop10e_large.bsp" =>
        "inpop10e/inpop10e_TDB_m1000_p1000_spice_release2.tar.gz",
      "inpop10e_large.bpc" =>
        "inpop10e/inpop10e_TDB_m1000_p1000_spice_release2.tar.gz",
      "inpop13c.bsp" => "inpop13c/inpop13c_TDB_m100_p100_spice.tar.gz",
      "inpop13c.bpc" => "inpop13c/inpop13c_TDB_m100_p100_spice.tar.gz",
      "inpop13c_time.bsp" => "inpop13c/inpop13c_TDB_m100_p100_spice.tar.gz",
      "inpop13c_large.bsp" => "inpop13c/inpop13c_TDB_m1000_p1000_spice.tar.gz",
      "inpop13c_large.bpc" => "inpop13c/inpop13c_TDB_m1000_p1000_spice.tar.gz",
      "inpop13c_large_time.bsp" =>
        "inpop13c/inpop13c_TDB_m1000_p1000_spice.tar.gz",
      "inpop17a.bsp" => "inpop17a/inpop17a_TDB_m100_p100_spice.tar.gz",
      "inpop17a.bpc" => "inpop17a/inpop17a_TDB_m100_p100_spice.tar.gz",
      "inpop17a_time.bsp" => "inpop17a/inpop17a_TDB_m100_p100_spice.tar.gz",
      "inpop17a_large.bsp" => "inpop17a/inpop17a_TDB_m1000_p1000_spice.tar.gz",
      "inpop17a_large.bpc" => "inpop17a/inpop17a_TDB_m1000_p1000_spice.tar.gz",
      "inpop17a_large_time.bsp" =>
        "inpop17a/inpop17a_TDB_m1000_p1000_spice.tar.gz",
      "inpop19a.bsp" => "inpop19a/inpop19a_TDB_m100_p100_spice.tar.gz",
      "inpop19a.bpc" => "inpop19a/inpop19a_TDB_m100_p100_spice.tar.gz",
      "inpop19a_time.bsp" => "inpop19a/inpop19a_TDB_m100_p100_spice.tar.gz",
      "inpop19a_large.bsp" => "inpop19a/inpop19a_TDB_m1000_p1000_spice.tar.gz",
      "inpop19a_large.bpc" => "inpop19a/inpop19a_TDB_m1000_p1000_spice.tar.gz",
      "inpop19a_large_time.bsp" =>
        "inpop19a/inpop19a_TDB_m1000_p1000_spice.tar.gz",
      "inpop21a.bsp" => "inpop21a/inpop21a_TDB_m100_p100_spice.tar.gz",
      "inpop21a.bpc" => "inpop21a/inpop21a_TDB_m100_p100_spice.tar.gz",
      "inpop21a_time.bsp" => "inpop21a/inpop21a_TDB_m100_p100_spice.tar.gz",
      "inpop21a_large.bsp" => "inpop21a/inpop21a_TDB_m1000_p1000_spice.tar.gz",
      "inpop21a_large.bpc" => "inpop21a/inpop21a_TDB_m1000_p1000_spice.tar.gz",
      "inpop21a_large_time.bsp" =>
        "inpop21a/inpop21a_TDB_m1000_p1000_spice.tar.gz"
    }.freeze

    SUPPORTED_KERNELS =
      (JPL_KERNELS + NAIF_PCK_KERNELS + IMCCE_KERNELS.keys).freeze

    def self.call(name:, target:)
      new(name, target).call
    end

    def initialize(name, target_path)
      @name = name
      @target_path = Pathname.new(target_path)
      validate_requested_kernel!
    end

    def call
      FileUtils.mkdir_p(@target_path.dirname)
      write_atomically { |file| download_kernel(file) }
      true
    end

    private

    def write_atomically
      partial_file = Tempfile.create(
        [".#{@target_path.basename}", ".part"],
        @target_path.dirname.to_s,
        binmode: true
      )
      begin
        yield partial_file
        partial_file.close
        File.chmod(0o666 & ~File.umask, partial_file.path)
        File.rename(partial_file.path, @target_path)
      ensure
        partial_file.close unless partial_file.closed?
        FileUtils.rm_f(partial_file.path)
      end
    end

    def download_kernel(file)
      if jpl_kernel?
        download_direct(JPL_BASE_URL, file)
      elsif pck_kernel?
        download_direct(NAIF_PCK_BASE_URL, file)
      else
        download_imcce(file)
      end
    end

    def validate_requested_kernel!
      unless SUPPORTED_KERNELS.include?(@name)
        raise UnsupportedError,
          "Kernel #{@name} is not supported by the library at the moment."
      end
    end

    def jpl_kernel?
      JPL_KERNELS.include?(@name)
    end

    def pck_kernel?
      NAIF_PCK_KERNELS.include?(@name)
    end

    def download_direct(base_url, file)
      stream_http_to_file(URI.join(base_url, @name), file)
    end

    def download_imcce(file)
      require "rubygems/package"

      tar_gz_uri = URI.join(IMCCE_BASE_URL, IMCCE_KERNELS_MATCHING[@name])
      Tempfile.create(%w[archive .tar.gz], binmode: true) do |temp_file|
        stream_http_to_file(tar_gz_uri, temp_file)
        temp_file.flush
        temp_file.rewind

        extract_imcce_kernel(temp_file.path, file)
      end
    end

    def extract_imcce_kernel(archive_path, file)
      kernel_path = IMCCE_KERNELS[@name]
      kernel_found = false
      Zlib::GzipReader.open(archive_path) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          tar.each_entry do |entry|
            next unless entry.full_name == kernel_path

            copy_entry(entry, file)
            kernel_found = true
            break
          end
        end
      end
      return if kernel_found

      raise DownloadError,
        "#{IMCCE_KERNELS_MATCHING[@name]} does not contain #{kernel_path}"
    end

    def copy_entry(entry, file)
      while (chunk = entry.read(ARCHIVE_READ_CHUNK_SIZE))
        file.write(chunk)
      end
    end

    def stream_http_to_file(uri, file)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https"
      ) do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request) do |response|
          unless response.is_a?(Net::HTTPSuccess)
            raise DownloadError,
              "Failed to download #{uri}: " \
              "#{response.code} #{response.message}"
          end

          response.read_body { |chunk| file.write(chunk) }
        end
      end
    end
  end
end
