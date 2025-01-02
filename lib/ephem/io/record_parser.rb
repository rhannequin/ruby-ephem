# frozen_string_literal: true

module Ephem
  module IO
    class RecordParser
      SUMMARY_CONTROL_SIZE = 24 # 3 doubles, 8 bytes each

      def initialize(endianness:)
        @endianness = endianness
      end

      def parse_file_record(file_record)
        data = file_record.unpack(record_format)
        RecordData.new(*data)
      end

      def parse_summary_control(data)
        format = "#{endian_double}3"
        values = data.unpack(format)
        {
          next_record: values[0].to_i,
          previous_record: values[1].to_i,
          n_summaries: values[2].to_i
        }
      end

      private

      def record_format
        @record_format ||= [
          "A8",             # Locator Identifier
          endian_uint32,    # Double Count
          endian_uint32,    # Integer Count
          "A60",            # Internal Filename
          endian_uint32,    # Forward Record Number
          endian_uint32,    # Backward Record Number
          endian_uint32,    # Free Record Number
          "A8",             # Format
          "A603",           # Reserved Area 1
          "A28",            # Fixed-length Transfer Protocol String
          "A297"            # Reserved Area 2
        ].join
      end

      def endian_uint32
        (@endianness == :little) ? "V" : "N"
      end

      def endian_double
        (@endianness == :little) ? "E" : "G"
      end
    end
  end
end
