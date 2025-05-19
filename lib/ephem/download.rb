# frozen_string_literal: true

require "minitar"
require "net/http"
require "pathname"
require "tempfile"
require "zlib"
require "fileutils"

module Ephem
  class Download
    JPL_BASE_URL = "https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/"
    IMCCE_BASE_URL = "https://ftp.imcce.fr/pub/ephem/planets/"

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
      de431.bsp
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
    ].freeze

    IMCCE_KERNELS = {
      "inpop10b.bsp" => "inpop10b_TDB_m100_p100_spice.bsp",
      "inpop10b_large.bsp" => "inpop10b_TDB_m1000_p1000_spice.bsp",
      "inpop10e.bsp" => "inpop10e_TDB_m100_p100_spice.bsp",
      "inpop10e_large.bsp" => "inpop10e_TDB_m1000_p1000_spice.bsp",
      "inpop13c.bsp" => "inpop13c_TDB_m100_p100_spice.bsp",
      "inpop13c_large.bsp" => "inpop13c_TDB_m1000_p1000_spice.bsp",
      "inpop17a.bsp" => "inpop17a_TDB_m100_p100_spice.bsp",
      "inpop17a_large.bsp" => "inpop17a_TDB_m1000_p1000_spice.bsp",
      "inpop19a.bsp" => "inpop19a_TDB_m100_p100_spice.bsp",
      "inpop19a_large.bsp" => "inpop19a_TDB_m1000_p1000_spice.bsp",
      "inpop21a.bsp" => "inpop21a_TDB_m100_p100_spice.bsp",
      "inpop21a_large.bsp" => "inpop21a_TDB_m1000_p1000_spice.bsp"
    }.freeze

    IMCCE_KERNELS_MATCHING = {
      "inpop10b.bsp" => "inpop10b/inpop10b_TDB_m100_p100_spice.tar.gz",
      "inpop10b_large.bsp" => "inpop10b/inpop10b_TDB_m1000_p1000_spice.tar.gz",
      "inpop10e.bsp" => "inpop10e/inpop10e_TDB_m100_p100_spice_release2.tar.gz",
      "inpop10e_large.bsp" =>
        "inpop10e/inpop10e_TDB_m1000_p1000_spice_release2.tar.gz",
      "inpop13c.bsp" => "inpop13c/inpop13c_TDB_m100_p100_spice.tar.gz",
      "inpop13c_large.bsp" => "inpop13c/inpop13c_TDB_m1000_p1000_spice.tar.gz",
      "inpop17a.bsp" => "inpop17a/inpop17a_TDB_m100_p100_spice.tar.gz",
      "inpop17a_large.bsp" => "inpop17a/inpop17a_TDB_m1000_p1000_spice.tar.gz",
      "inpop19a.bsp" => "inpop19a/inpop19a_TDB_m100_p100_spice.tar.gz",
      "inpop19a_large.bsp" => "inpop19a/inpop19a_TDB_m1000_p1000_spice.tar.gz",
      "inpop21a.bsp" => "inpop21a/inpop21a_TDB_m100_p100_spice.tar.gz",
      "inpop21a_large.bsp" => "inpop21a/inpop21a_TDB_m1000_p1000_spice.tar.gz"
    }.freeze

    SUPPORTED_KERNELS = (JPL_KERNELS + IMCCE_KERNELS.keys).freeze

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
      jpl_kernel? ? download_jpl : download_imcce
      true
    end

    private

    def validate_requested_kernel!
      unless SUPPORTED_KERNELS.include?(@name)
        raise UnsupportedError,
          "Kernel #{@name} is not supported by the library at the moment."
      end
    end

    def jpl_kernel?
      JPL_KERNELS.include?(@name)
    end

    def download_jpl
      uri = URI.join(JPL_BASE_URL, @name)
      @target_path.open("wb") do |file|
        stream_http_to_file(uri, file)
      end
    end

    def download_imcce
      tar_gz_uri = URI.join(IMCCE_BASE_URL, IMCCE_KERNELS_MATCHING[@name])
      Tempfile.create(%w[archive .tar.gz]) do |temp_file|
        stream_http_to_file(tar_gz_uri, temp_file)
        temp_file.flush
        temp_file.rewind

        Zlib::GzipReader.open(temp_file.path) do |gz|
          Minitar::Reader.open(gz) do |tar|
            tar.each_entry do |entry|
              next unless entry.full_name == IMCCE_KERNELS[@name]

              @target_path.open("wb") { |file| file.write(entry.read) }

              break
            end
          end
        end
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
          response.read_body { |chunk| file.write(chunk) }
        end
      end
    end
  end
end
