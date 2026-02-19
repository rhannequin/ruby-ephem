# frozen_string_literal: true

module Ephem
  module IO
    # The SummaryManager class handles the parsing and iteration of summary
    # records in a Double Precision Array File (DAF). It manages the extraction
    # of summary records and their associated names, handling both little and
    # big endian formats.
    #
    # Each summary record consists of:
    # * Control information (24 bytes)
    # * Multiple summary entries (variable length)
    # * Associated name entries in the following record
    #
    # The class provides iteration capabilities over all summaries in the file,
    # handling record chains and proper binary unpacking based on the file's
    # endianness.
    #
    # @example Basic usage
    #   binary_reader = Ephem::IO::BinaryReader.new(file)
    #   record_data = Ephem::IO::RecordParser
    #     .new
    #     .parse_file_record(first_record)
    #   manager = Ephem::IO::SummaryManager.new(
    #     record_data: record_data,
    #     binary_reader: binary_reader,
    #     endianness: :little
    #   )
    #
    #   manager.each_summary do |name, values|
    #     puts "Summary #{name}: #{values.inspect}"
    #   end
    #
    # @example Using as an enumerator
    #   summaries = manager.each_summary.map do |name, values|
    #     { name: name, doubles: values[0..1], integer: values[2] }
    #   end
    #
    # @api public
    class SummaryManager
      SUMMARY_RECORD_SIZE = 1024
      VALID_ENDIANNESS = [:little, :big].freeze

      # Initializes a new SummaryManager instance
      #
      # @param record_data [RecordData] Data extracted from the file record,
      #   containing information about doubles count, integers count, and record
      #   chain navigation
      # @param binary_reader [BinaryReader] Reader instance for accessing binary
      #   data from the DAF file
      # @param endianness [Symbol] Endianness of the binary data, either :little
      #   or :big
      #
      # @raise [ArgumentError] If endianness is neither :little nor :big
      def initialize(record_data:, binary_reader:, endianness:)
        validate_endianness!(endianness)
        @record_data = record_data
        @binary_reader = binary_reader
        @endianness = endianness
        @record_parser = RecordParser.new(endianness: @endianness)
        setup_summary_format
      end

      # Iterates through each summary in the DAF file
      #
      # This method traverses the chain of summary records, extracting both the
      # summary data and associated names. It handles proper binary unpacking
      # based on the file's endianness and the record format specification.
      #
      # If no block is given, returns an Enumerator for the summaries.
      #
      # @yield [name, values] Yields each summary's name and values
      # @yieldparam name [String] The name associated with the summary
      # @yieldparam values [Array<Float, Integer>] Array containing the summary
      #   values, with doubles followed by integers according to the record
      #   format
      #
      # @return [Enumerator] If no block given, returns an Enumerator that will
      #   iterate over all summaries
      # @return [nil] If block given, returns nil after iteration completes
      def each_summary
        return to_enum(__method__) unless block_given?

        iterate_summary_chain(@record_data.forward_record) do |name, values|
          yield name, values
        end
      end

      private

      def validate_endianness!(endianness)
        return if VALID_ENDIANNESS.include?(endianness)

        raise EndiannessError,
          "Invalid endianness: #{endianness}. Must be one of: #{VALID_ENDIANNESS.join(", ")}"
      end

      def setup_summary_format
        @summary_format = build_summary_format
        @summary_length = calculate_summary_length
        @summary_step = calculate_summary_step
        @summaries_per_record = calculate_summaries_per_record
      end

      def build_summary_format
        doubles_format = "#{endian_double}#{@record_data.double_count}"
        integers_format = "#{endian_uint32}#{@record_data.integer_count}"
        doubles_format + integers_format
      end

      def calculate_summary_length
        # Calculate size of the summary in bytes
        (@record_data.double_count * 8) + (@record_data.integer_count * 4)
      end

      def calculate_summary_step
        # Pad to 8-byte boundary
        @summary_length + (-@summary_length % 8)
      end

      def calculate_summaries_per_record
        (
          SUMMARY_RECORD_SIZE - RecordParser::SUMMARY_CONTROL_SIZE
        ) / @summary_step
      end

      def iterate_summary_chain(record_number)
        while record_number != 0
          record_number =
            process_summary_record(record_number) do |name, values|
              yield name, values
            end
        end
      end

      def process_summary_record(record_number)
        data = @binary_reader.read_record(record_number)
        control = parse_control_data(data)
        summary_data = extract_summary_data(data)
        name_data = @binary_reader.read_record(record_number + 1)

        process_summaries(
          control[:n_summaries],
          summary_data,
          name_data
        ) do |name, values|
          yield name, values
        end

        control[:next_record]
      end

      def parse_control_data(data)
        @record_parser.parse_summary_control(
          data[0, RecordParser::SUMMARY_CONTROL_SIZE]
        )
      end

      def extract_summary_data(data)
        data[RecordParser::SUMMARY_CONTROL_SIZE..]
      end

      def process_summaries(count, summary_data, name_data)
        count.times do |i|
          offset = i * @summary_step
          values = extract_values(summary_data[offset, @summary_length])
          name = extract_name(name_data[offset, @summary_step])
          yield name, values
        end
      end

      def extract_values(data)
        return [] if data.nil? || data.empty?

        data.unpack(@summary_format)
      end

      def extract_name(data)
        return "" if data.nil? || data.empty?

        data.strip
      end

      def endian_double
        BinaryReader::ENDIANNESS_DOUBLE_FORMATS[@endianness]
      end

      def endian_uint32
        BinaryReader::ENDIANNESS_UINT32_FORMATS[@endianness]
      end
    end
  end
end
