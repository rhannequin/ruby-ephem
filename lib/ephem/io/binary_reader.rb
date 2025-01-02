# frozen_string_literal: true

module Ephem
  module IO
    class BinaryReader
      RECORD_SIZE = 1024

      def initialize(file_object)
        validate_file_object(file_object)
        @file = file_object

        # Create a Mutex for thread-safe access to the file
        # Mutex ensures that only one thread can access the critical section at
        # a time. This prevents race conditions and data corruption when
        # multiple threads read from the file simultaneously
        @lock = Mutex.new
      end

      def read_record(record_number)
        validate_record_number(record_number)

        @lock.synchronize do
          seek_to_record(record_number)
          read_and_pad_record
        end
      end

      def read_array(start_word:, end_word:, endianness:)
        validate_array_bounds(start_word, end_word)
        length = end_word - start_word + 1

        # Use the Mutex to synchronize access to the file only one thread can
        # enter this critical section at a time. This ensures atomic reads of
        # the array data, preventing data corruption
        @lock.synchronize do
          seek_to_word(start_word)
          read_array_data(length, endianness)
        end
      end

      def close
        @file.close
      end

      private

      def validate_file_object(file_object)
        unless file_object.respond_to?(:read) && file_object.respond_to?(:seek)
          raise ArgumentError,
            "file_object must be an IO-like object with read and seek capabilities"
        end

        unless file_object.binmode?
          raise ArgumentError,
            "file_object must be opened in binary mode"
        end
      end

      def validate_record_number(record_number)
        unless record_number.positive?
          raise ArgumentError,
            "Record number must be positive, got: #{record_number}"
        end
      end

      def validate_array_bounds(start_word, end_word)
        unless start_word <= end_word
          raise ArgumentError,
            "Invalid array bounds: start_word (#{start_word}) must be <= end_word (#{end_word})"
        end
      end

      def seek_to_record(record_number)
        @file.seek((record_number - 1) * RECORD_SIZE, ::IO::SEEK_SET)
      end

      def seek_to_word(word)
        @file.seek(8 * (word - 1), ::IO::SEEK_SET)
      end

      def read_and_pad_record
        data = @file.read(RECORD_SIZE)
        raise IOError, "Failed to read record" unless data
        data.ljust(RECORD_SIZE, "\0")
      end

      def read_array_data(length, endianness)
        data = @file.read(8 * length)
        raise IOError, "Failed to read array" unless data
        data.unpack("#{endianness_format(endianness)}#{length}")
      end

      def endianness_format(endianness)
        case endianness
        when :little then "E"
        when :big then "G"
        else raise ArgumentError, "Invalid endianness: #{endianness}"
        end
      end
    end
  end
end
