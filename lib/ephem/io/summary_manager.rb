# frozen_string_literal: true

module Ephem
  module IO
    class SummaryManager
      def initialize(record_data:, binary_reader:, endianness:)
        @record_data = record_data
        @binary_reader = binary_reader
        @endianness = endianness
        @parser = RecordParser.new(endianness: endianness)
        setup_summary_format
      end

      def each_summary
        return enum_for(:each_summary) unless block_given?

        record_number = @record_data.forward_record
        while record_number != 0
          process_summary_record(record_number) do |name, values|
            yield name, values
          end
          record_number = get_next_record(record_number)
        end
      end

      private

      def setup_summary_format
        @summary_format = build_summary_format
        @summary_length = calculate_summary_length
        @summary_step = calculate_summary_step
        @summaries_per_record = calculate_summaries_per_record
      end

      def build_summary_format
        doubles = "#{endian_double}#{@record_data.double_count}"
        integers = "#{endian_uint32}#{@record_data.integer_count}"
        doubles + integers
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
        (1024 - RecordParser::SUMMARY_CONTROL_SIZE) / @summary_step
      end

      def process_summary_record(record_number)
        data = @binary_reader.read_record(record_number)
        control = @parser.parse_summary_control(
          data[0, RecordParser::SUMMARY_CONTROL_SIZE]
        )

        summary_data = extract_summary_data(data)
        name_data = @binary_reader.read_record(record_number + 1)

        process_summaries(control[:n_summaries], summary_data, name_data) do |name, values|
          yield name, values
        end
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
        data.unpack(@summary_format)
      end

      def extract_name(data)
        data.strip
      end

      def get_next_record(record_number)
        data = @binary_reader.read_record(record_number)
        control = @parser.parse_summary_control(
          data[0, RecordParser::SUMMARY_CONTROL_SIZE]
        )
        control[:next_record]
      end

      def endian_double
        (@endianness == :little) ? "E" : "G"
      end

      def endian_uint32
        (@endianness == :little) ? "V" : "N"
      end
    end
  end
end
