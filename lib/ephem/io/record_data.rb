# frozen_string_literal: true

module Ephem
  module IO
    class RecordData
      attr_reader :locator_identifier, :double_count, :integer_count,
        :internal_filename, :forward_record, :backward_record, :free_record,
        :format, :reserved_area_1, :ftpstr, :reserved_area_2

      def initialize(*data)
        @locator_identifier, @double_count, @integer_count, @internal_filename,
          @forward_record, @backward_record, @free_record, @format,
          @reserved_area_1, @ftpstr, @reserved_area_2 = data

        convert_numeric_fields
        strip_text_fields
      end

      private

      def convert_numeric_fields
        @double_count = @double_count.to_i
        @integer_count = @integer_count.to_i
        @forward_record = @forward_record.to_i
        @backward_record = @backward_record.to_i
        @free_record = @free_record.to_i
      end

      def strip_text_fields
        @internal_filename = @internal_filename.rstrip
        @format = @format.rstrip
        @reserved_area_1 = @reserved_area_1.rstrip
        @ftpstr = @ftpstr.rstrip
        @reserved_area_2 = @reserved_area_2.rstrip
      end
    end
  end
end
