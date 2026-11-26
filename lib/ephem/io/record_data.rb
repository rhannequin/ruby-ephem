# frozen_string_literal: true

module Ephem
  module IO
    class RecordData
      attr_reader :locator_identifier, :double_count, :integer_count,
        :internal_filename, :forward_record

      def initialize(*data)
        @locator_identifier, @double_count, @integer_count, @internal_filename,
          @forward_record = data

        @double_count = @double_count.to_i
        @integer_count = @integer_count.to_i
        @forward_record = @forward_record.to_i
        @internal_filename = @internal_filename.rstrip
      end
    end
  end
end
