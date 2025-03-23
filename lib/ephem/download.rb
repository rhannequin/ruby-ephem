# frozen_string_literal: true

require "net/http"

module Ephem
  class Download
    BASE_URL = "https://ssd.jpl.nasa.gov/ftp/eph/planets/bsp/"

    SUPPORTED_KERNELS = %w[
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

    def self.call(name:, target:)
      new(name, target).call
    end

    def initialize(name, local_path)
      @name = name
      @local_path = local_path
      validate_requested_kernel!
    end

    def call
      uri = URI("#{BASE_URL}#{@name}")
      content = Net::HTTP.get(uri)
      File.write(@local_path, content)

      true
    end

    private

    def validate_requested_kernel!
      unless SUPPORTED_KERNELS.include?(@name)
        raise UnsupportedError,
          "Kernel #{@name} is not supported by the library at the moment."
      end
    end
  end
end
