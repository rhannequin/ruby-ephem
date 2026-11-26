# frozen_string_literal: true

require "stringio"

RSpec.describe Ephem::IO::BinaryReader do
  describe ".new" do
    it "raises ArgumentError for an object that cannot read and seek" do
      expect { Ephem::IO::BinaryReader.new(Object.new) }.to raise_error(
        ArgumentError,
        "file_object must be an IO-like object with read and seek capabilities"
      )
    end

    it "raises ArgumentError for an IO not in binary mode" do
      File.open(__FILE__, "r") do |text_file|
        expect { Ephem::IO::BinaryReader.new(text_file) }.to raise_error(
          ArgumentError,
          "file_object must be opened in binary mode"
        )
      end
    end
  end

  describe "#read_record" do
    it "returns the requested record" do
      first_record = "a" * Ephem::IO::BinaryReader::RECORD_SIZE
      second_record = "b" * Ephem::IO::BinaryReader::RECORD_SIZE
      reader = build_reader(first_record + second_record)

      expect(reader.read_record(2)).to eq(second_record)
    end

    it "raises FileFormatError when the record is only partly present" do
      reader = build_reader("abc")

      expect { reader.read_record(1) }.to raise_error(
        Ephem::FileFormatError,
        "Truncated file: expected 1024 bytes of record 1, got 3"
      )
    end

    it "raises ArgumentError for a non-positive record number" do
      reader = build_reader("abc")

      expect { reader.read_record(0) }.to raise_error(
        ArgumentError,
        "Record number must be positive, got: 0"
      )
    end

    it "raises FileFormatError when the record is past the end of the file" do
      reader = build_reader("abc")

      expect { reader.read_record(2) }.to raise_error(
        Ephem::FileFormatError,
        "Truncated file: expected 1024 bytes of record 2, got 0"
      )
    end

    it "raises FileFormatError when the file is empty" do
      reader = build_reader("")

      expect { reader.read_record(1) }.to raise_error(
        Ephem::FileFormatError,
        "Truncated file: expected 1024 bytes of record 1, got 0"
      )
    end
  end

  describe "#read_array" do
    it "reads little-endian doubles between the given words" do
      reader = build_reader([1.0, 2.0, 3.0, 4.0].pack("E4"))

      values = reader.read_array(
        start_word: 2,
        end_word: 3,
        endianness: :little
      )

      expect(values).to eq([2.0, 3.0])
    end

    it "reads big-endian doubles between the given words" do
      reader = build_reader([1.0, 2.0, 3.0].pack("G3"))

      values = reader.read_array(start_word: 1, end_word: 3, endianness: :big)

      expect(values).to eq([1.0, 2.0, 3.0])
    end

    it "raises ArgumentError when start_word is after end_word" do
      reader = build_reader([1.0, 2.0].pack("E2"))

      expect {
        reader.read_array(start_word: 2, end_word: 1, endianness: :little)
      }.to raise_error(
        ArgumentError,
        "Invalid array bounds: start_word (2) must be <= end_word (1)"
      )
    end

    it "raises ArgumentError for an unknown endianness" do
      reader = build_reader([1.0].pack("E"))

      expect {
        reader.read_array(start_word: 1, end_word: 3, endianness: :middle)
      }.to raise_error(ArgumentError, "Invalid endianness: middle")
    end

    it "raises FileFormatError when the file is truncated" do
      reader = build_reader([1.0].pack("E"))

      expect {
        reader.read_array(start_word: 1, end_word: 3, endianness: :little)
      }.to raise_error(
        Ephem::FileFormatError,
        "Truncated file: expected 24 bytes of array data, got 8"
      )
    end

    it "raises FileFormatError when the last double is incomplete" do
      reader = build_reader([1.0].pack("E") + "\0" * 4)

      expect {
        reader.read_array(start_word: 1, end_word: 2, endianness: :little)
      }.to raise_error(
        Ephem::FileFormatError,
        "Truncated file: expected 16 bytes of array data, got 12"
      )
    end

    it "raises FileFormatError when the array starts past the end" do
      reader = build_reader([1.0].pack("E"))

      expect {
        reader.read_array(start_word: 5, end_word: 6, endianness: :little)
      }.to raise_error(
        Ephem::FileFormatError,
        "Truncated file: expected 16 bytes of array data, got 0"
      )
    end
  end

  describe "#close" do
    it "closes the underlying file" do
      binary_io = build_binary_io([1.0].pack("E"))
      reader = Ephem::IO::BinaryReader.new(binary_io)

      reader.close

      expect(binary_io).to be_closed
    end

    it "makes later reads raise a ClosedKernelError" do
      reader = build_reader([1.0].pack("E") * 128)

      reader.close

      expect { reader.read_record(1) }.to raise_error(
        Ephem::ClosedKernelError, "Cannot read from a closed kernel"
      )
      expect {
        reader.read_array(start_word: 1, end_word: 1, endianness: :little)
      }.to raise_error(Ephem::ClosedKernelError)
    end

    it "reads from a file object that cannot tell whether it is closed" do
      binary_io = build_binary_io([1.0].pack("E"))
      binary_io.singleton_class.undef_method(:closed?)
      reader = Ephem::IO::BinaryReader.new(binary_io)

      expect(
        reader.read_array(start_word: 1, end_word: 1, endianness: :little)
      ).to eq([1.0])
    end
  end

  def build_reader(bytes)
    Ephem::IO::BinaryReader.new(build_binary_io(bytes))
  end

  def build_binary_io(bytes)
    binary_io = StringIO.new(bytes.b).binmode
    binary_io.define_singleton_method(:binmode?) { true }
    binary_io
  end
end
