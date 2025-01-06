# frozen_string_literal: true

module Ephem
  class Error < StandardError; end

  class FileFormatError < Error; end

  class CommentError < Error; end

  class EndiannessError < Error; end

  class UnsupportedError < Error; end

  class InvalidInputError < Error; end

  class OutOfRangeError < StandardError
    attr_reader :out_of_range_times

    def initialize(message, out_of_range_times)
      super(message)
      @out_of_range_times = out_of_range_times
    end
  end
end
