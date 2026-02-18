# frozen_string_literal: true

module Ephem
  module IO
    class DAF
      attr_reader :binary_reader, :record_data, :endianness

      def initialize(file_object)
        @binary_reader = BinaryReader.new(file_object)
        setup_file_format
        setup_summary_manager
      end

      def comments
        @comments ||= load_comments
      end

      def summaries(&block)
        return enum_for(:summaries) unless block_given?

        @summary_manager.each_summary(&block)
      end

      def read_array(start_word, end_word)
        @binary_reader.read_array(
          start_word: start_word,
          end_word: end_word,
          endianness: @endianness
        )
      end
      alias_method :map_array, :read_array

      def close
        @binary_reader&.close
      end

      private

      def setup_file_format
        file_record = @binary_reader.read_record(1)
        endianness_info = EndiannessManager.new(file_record).detect_endianness

        @endianness = endianness_info[:endianness]
        @record_parser = RecordParser.new(endianness: @endianness)
        @record_data = @record_parser.parse_file_record(file_record)
      end

      def setup_summary_manager
        @summary_manager = SummaryManager.new(
          record_data: @record_data,
          binary_reader: @binary_reader,
          endianness: @endianness
        )
      end

      def load_comments
        comment_records = (2...@record_data.forward_record).to_a
        return "" if comment_records.empty?

        read_comment_records(comment_records).then do |data|
          parse_comment_data(data)
        end
      end

      def read_comment_records(record_numbers)
        record_numbers.map do |record_number|
          @binary_reader.read_record(record_number)[0, 1000]
        end.join
      end

      def parse_comment_data(data)
        eot_index = data.index("\x04") or
          raise CommentError, "DAF file comment area is missing its EOT byte"

        data[0...eot_index].tr("\0", "\n")
      end
    end
  end
end
