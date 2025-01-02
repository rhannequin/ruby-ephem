# frozen_string_literal: true

module Ephem
  module IO
    class EndiannessManager
      # Mapping of format to endianness
      FORMATS = {
        "BIG-IEEE" => :big,
        "LTL-IEEE" => :little
      }.freeze

      # Fixed-length Transfer Protocol String
      FTPSTR = "FTPSTR:\r:\n:\r\n:\r\x00:\x81:\x10\xce:ENDFTP".b.freeze

      def initialize(file_record)
        @file_record = file_record
        @locator_identifier = extract_locator_identifier
      end

      def detect_endianness
        case @locator_identifier
        when "NAIF/DAF" then detect_from_naif_daf
        when /\ADAF\// then detect_from_daf_prefix
        else
          raise FileFormatError,
            "Invalid file identifier: #{@locator_identifier.inspect}"
        end
      end

      private

      def extract_locator_identifier
        @file_record[0, 8].upcase.rstrip
      end

      def detect_from_naif_daf
        FORMATS.each do |format, endian|
          if valid_format?(format, endian)
            return {format: format, endianness: endian}
          end
        end
        raise EndiannessError, "Unable to determine file endianness"
      end

      def detect_from_daf_prefix
        validate_ftpstr
        format = extract_format
        endianness = FORMATS.fetch(format) do
          raise FileFormatError, "Unknown format #{format.inspect}"
        end

        {format: format, endianness: endianness}
      end

      def validate_ftpstr
        # The Fixed-length Transfer Protocol String (FTPSTR) is expected to be
        # found in bytes 501-1000 of the file record. If it's not present, the
        # file is considered damaged.
        #
        # The file format and endianness are determined from bytes 89-96 of the
        # file record. If the format is unknown, an exception is raised.
        #
        # Finally, the file record is unpacked using the determined format and
        # endianness.
        ftpstr_section = @file_record[500, 500].gsub(/\A\0+|\0+\z/, "")
        unless ftpstr_section == FTPSTR
          raise FileFormatError, "This SPK file has been damaged"
        end
      end

      def extract_format
        @file_record[88, 8].strip
      end

      def valid_format?(format, endian)
        temp_parser = RecordParser.new(endianness: endian)
        record_data = temp_parser.parse_file_record(@file_record)
        record_data.double_count == 2
      rescue
        false
      end
    end
  end
end
