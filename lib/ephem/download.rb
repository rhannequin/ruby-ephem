# frozen_string_literal: true

require "minitar"
require "net/http"
require "tempfile"
require "zlib"

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

    def initialize(name, local_path)
      @name = name
      @local_path = local_path
      validate_requested_kernel!
    end

    def call
      content = jpl_kernel? ? download_from_jpl : download_from_imcce
      File.binwrite(@local_path, content)

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

    def download_from_jpl
      uri = URI("#{JPL_BASE_URL}#{@name}")
      Net::HTTP.get(uri)
    end

    def download_from_imcce
      temp_file = Tempfile.new(%w[archive .tar.gz])
      uri = URI("#{IMCCE_BASE_URL}#{IMCCE_KERNELS_MATCHING[@name]}")
      content = Net::HTTP.get(uri)
      temp_file.write(content)
      temp_file.rewind

      Zlib::GzipReader.open(temp_file.path) do |gz|
        Minitar::Reader.open(gz) do |tar|
          tar.each_entry do |entry|
            return entry.read if entry.full_name == IMCCE_KERNELS[@name]
          end
        end
      end
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
end
