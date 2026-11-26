# frozen_string_literal: true

RSpec.describe Ephem::IO::SummaryManager do
  describe "#each_summary" do
    it "returns an enumerator when no block is given" do
      record_data = instance_double(
        Ephem::IO::RecordData,
        double_count: 2,
        integer_count: 1,
        forward_record: 5
      )
      binary_reader = instance_double(Ephem::IO::BinaryReader)
      summary_manager = Ephem::IO::SummaryManager.new(
        record_data: record_data,
        binary_reader: binary_reader,
        endianness: :little
      )

      expect(summary_manager.each_summary).to be_an(Enumerator)
    end

    it "raises EndiannessError for invalid endianness" do
      record_data = instance_double(
        Ephem::IO::RecordData,
        double_count: 2,
        integer_count: 1,
        forward_record: 5
      )
      binary_reader = instance_double(Ephem::IO::BinaryReader)

      expect {
        Ephem::IO::SummaryManager.new(
          record_data: record_data,
          binary_reader: binary_reader,
          endianness: :invalid
        )
      }.to raise_error(
        Ephem::EndiannessError,
        "Invalid endianness: invalid. Must be one of: little, big"
      )
    end

    it "yields summaries with correct values for little endian" do
      record_data = instance_double(
        Ephem::IO::RecordData,
        double_count: 2,
        integer_count: 1,
        forward_record: 5
      )
      binary_reader = instance_double(Ephem::IO::BinaryReader)
      record_parser = instance_double(Ephem::IO::RecordParser)

      allow(Ephem::IO::RecordParser).to receive(:new)
        .with(endianness: :little)
        .and_return(record_parser)

      # Create a full 1024-byte record
      summary_record = [
        [0.0, 0.0, 2.0].pack("E3"), # Control record (24 bytes)

        # First summary (24 bytes = 16 for doubles + 4 for integer + 4 padding)
        [1.0, 2.0].pack("E2"),
        [3].pack("V"),

        "\0" * 4,  # Padding to 24 bytes

        # Second summary (24 bytes)
        [4.0, 5.0].pack("E2"),
        [6].pack("V"),

        "\0" * 4  # Padding to 24 bytes
      ].join
      # Pad the rest of the record to 1024 bytes
      summary_record << "\0" * (1024 - summary_record.length)

      # Names record, also 1024 bytes
      names_record = [
        "name1".ljust(24, "\0"),
        "name2".ljust(24, "\0"),
        "\0" * (1024 - 48)
      ].join

      allow(record_parser).to receive(:parse_summary_control)
        .with(summary_record[0, 24])
        .and_return({next_record: 0, previous_record: 0, summary_count: 2})

      allow(binary_reader).to receive(:read_record)
        .with(5)
        .and_return(summary_record)

      allow(binary_reader).to receive(:read_record)
        .with(6)
        .and_return(names_record)

      summary_manager = Ephem::IO::SummaryManager.new(
        record_data: record_data,
        binary_reader: binary_reader,
        endianness: :little
      )

      summaries = []
      summary_manager
        .each_summary { |name, values| summaries << [name, values] }

      expect(summaries).to eq([
        ["name1", [1.0, 2.0, 3]],
        ["name2", [4.0, 5.0, 6]]
      ])
    end

    it "yields summaries with correct values for big endian" do
      record_data = instance_double(
        Ephem::IO::RecordData,
        double_count: 2,
        integer_count: 1,
        forward_record: 5
      )
      binary_reader = instance_double(Ephem::IO::BinaryReader)
      record_parser = instance_double(Ephem::IO::RecordParser)

      allow(Ephem::IO::RecordParser).to receive(:new)
        .with(endianness: :big)
        .and_return(record_parser)

      # Create a full 1024-byte record
      summary_record = [
        [0.0, 0.0, 2.0].pack("G3"), # Control record (24 bytes)

        # First summary (24 bytes = 16 for doubles + 4 for integer + 4 padding)
        [1.0, 2.0].pack("G2"),
        [3].pack("N"),

        "\0" * 4,  # Padding to 24 bytes

        # Second summary (24 bytes)
        [4.0, 5.0].pack("G2"),
        [6].pack("N"),

        "\0" * 4  # Padding to 24 bytes
      ].join
      # Pad the rest of the record to 1024 bytes
      summary_record << "\0" * (1024 - summary_record.length)

      # Names record, also 1024 bytes
      names_record = [
        "name1".ljust(24, "\0"),
        "name2".ljust(24, "\0"),
        "\0" * (1024 - 48)  # Pad the rest to 1024 bytes
      ].join

      allow(record_parser).to receive(:parse_summary_control)
        .with(summary_record[0, 24])
        .and_return({next_record: 0, previous_record: 0, summary_count: 2})

      allow(binary_reader).to receive(:read_record)
        .with(5)
        .and_return(summary_record)

      allow(binary_reader).to receive(:read_record)
        .with(6)
        .and_return(names_record)

      summary_manager = Ephem::IO::SummaryManager.new(
        record_data: record_data,
        binary_reader: binary_reader,
        endianness: :big
      )

      summaries = []
      summary_manager
        .each_summary { |name, values| summaries << [name, values] }

      expect(summaries).to eq([
        ["name1", [1.0, 2.0, 3]],
        ["name2", [4.0, 5.0, 6]]
      ])
    end

    it "processes multiple records in chain" do
      record_data = instance_double(
        Ephem::IO::RecordData,
        double_count: 2,
        integer_count: 1,
        forward_record: 5
      )
      binary_reader = instance_double(Ephem::IO::BinaryReader)
      record_parser = instance_double(Ephem::IO::RecordParser)

      allow(Ephem::IO::RecordParser).to receive(:new)
        .with(endianness: :little)
        .and_return(record_parser)

      # First record (1024 bytes)
      first_record = [
        # Control with next_record = 7
        [7.0, 0.0, 2.0].pack("E3"),

        # First summary
        [1.0, 2.0].pack("E2"),
        [3].pack("V"),

        "\0" * 4, # Padding

        # Second summary
        [4.0, 5.0].pack("E2"),
        [6].pack("V"),

        "\0" * 4 # Padding
      ].join
      # Pad the rest of the record to 1024 bytes
      first_record << "\0" * (1024 - first_record.length)

      # First names record (1024 bytes)
      first_names = [
        "name1".ljust(24, "\0"),
        "name2".ljust(24, "\0"),
        "\0" * (1024 - 48)
      ].join

      # Second record (1024 bytes)
      second_record = [
        # Control with next_record = 0
        [0.0, 5.0, 1.0].pack("E3"),

        # Third summary
        [7.0, 8.0].pack("E2"),
        [9].pack("V"),

        "\0" * 4 # Padding
      ].join
      # Pad the rest of the record to 1024 bytes
      second_record << "\0" * (1024 - second_record.length)

      # Second names record (1024 bytes)
      second_names = [
        "name3".ljust(24, "\0"),
        "\0" * (1024 - 24)
      ].join

      allow(record_parser).to receive(:parse_summary_control)
        .with(first_record[0, 24])
        .and_return({next_record: 7, previous_record: 0, summary_count: 2})

      allow(record_parser).to receive(:parse_summary_control)
        .with(second_record[0, 24])
        .and_return({next_record: 0, previous_record: 5, summary_count: 1})

      allow(binary_reader).to receive(:read_record)
        .with(5)
        .and_return(first_record)

      allow(binary_reader).to receive(:read_record)
        .with(6)
        .and_return(first_names)

      allow(binary_reader).to receive(:read_record)
        .with(7)
        .and_return(second_record)

      allow(binary_reader).to receive(:read_record)
        .with(8)
        .and_return(second_names)

      summary_manager = Ephem::IO::SummaryManager.new(
        record_data: record_data,
        binary_reader: binary_reader,
        endianness: :little
      )

      summaries = []
      summary_manager
        .each_summary { |name, values| summaries << [name, values] }

      expect(summaries).to eq([
        ["name1", [1.0, 2.0, 3]],
        ["name2", [4.0, 5.0, 6]],
        ["name3", [7.0, 8.0, 9]]
      ])
    end

    it "raises FileFormatError when a summary record points to itself" do
      file = build_daf_file(5 => 5)
      summary_manager = build_summary_manager(file, forward_record: 5)

      expect { summary_manager.each_summary.to_a }.to raise_error(
        Ephem::FileFormatError,
        "Summary record chain loops back to record 5"
      )
    end

    it "raises FileFormatError when the chain loops to an earlier record" do
      file = build_daf_file(3 => 5, 5 => 7, 7 => 3)
      summary_manager = build_summary_manager(file, forward_record: 3)

      expect { summary_manager.each_summary.to_a }.to raise_error(
        Ephem::FileFormatError,
        "Summary record chain loops back to record 3"
      )
    end

    it "follows a chain that points backwards without repeating" do
      file = build_daf_file(3 => 0, 7 => 3)
      summary_manager = build_summary_manager(file, forward_record: 7)

      names = summary_manager.each_summary.map { |name, _values| name }

      expect(names).to eq(["summary_7", "summary_3"])
    end

    it "yields summaries read before detecting a loop" do
      file = build_daf_file(3 => 5, 5 => 3)
      summary_manager = build_summary_manager(file, forward_record: 3)
      names = []

      expect {
        summary_manager.each_summary { |name, _values| names << name }
      }.to raise_error(Ephem::FileFormatError)
      expect(names).to eq(["summary_3", "summary_5"])
    end

    it "raises FileFormatError when a record points to a negative record" do
      file = build_daf_file(3 => -2)
      summary_manager = build_summary_manager(file, forward_record: 3)

      expect { summary_manager.each_summary.to_a }.to raise_error(
        Ephem::FileFormatError,
        "Invalid summary record number: -2"
      )
    end

    it "raises FileFormatError when the forward record is negative" do
      file = build_daf_file(3 => 0)
      summary_manager = build_summary_manager(file, forward_record: -1)

      expect { summary_manager.each_summary.to_a }.to raise_error(
        Ephem::FileFormatError,
        "Invalid summary record number: -1"
      )
    end

    it "unpacks summary integers as signed for little endian" do
      expect(single_summary_values(endianness: :little, integer: -82))
        .to eq [1.0, 2.0, -82]
    end

    it "unpacks summary integers as signed for big endian" do
      expect(single_summary_values(endianness: :big, integer: -82))
        .to eq [1.0, 2.0, -82]
    end
  end

  def build_daf_file(next_records)
    last_record = next_records.keys.max + 1
    records = Array.new(last_record) { "\0" * 1024 }

    next_records.each do |record_number, next_record|
      records[record_number - 1] = build_summary_record(next_record)
      records[record_number] = "summary_#{record_number}".ljust(1024, "\0")
    end

    StringIO.new(records.join).binmode
  end

  def build_summary_record(next_record)
    control = [next_record.to_f, 0.0, 1.0].pack("E3")
    summary = [1.0, 2.0].pack("E2") + [3].pack("V")
    (control + summary).ljust(1024, "\0")
  end

  def build_summary_manager(file, forward_record:)
    record_data = instance_double(
      Ephem::IO::RecordData,
      double_count: 2,
      integer_count: 1,
      forward_record: forward_record
    )

    Ephem::IO::SummaryManager.new(
      record_data: record_data,
      binary_reader: build_binary_reader(file),
      endianness: :little
    )
  end

  def build_binary_reader(file)
    binary_reader = instance_double(Ephem::IO::BinaryReader)
    allow(binary_reader).to receive(:read_record) do |record_number|
      file.seek((record_number - 1) * 1024)
      file.read(1024)
    end
    binary_reader
  end

  def single_summary_values(endianness:, integer:)
    double_format, integer_format =
      (endianness == :little) ? ["E", "l<"] : ["G", "l>"]
    record_data = instance_double(
      Ephem::IO::RecordData,
      double_count: 2,
      integer_count: 1,
      forward_record: 5
    )
    binary_reader = instance_double(Ephem::IO::BinaryReader)
    summary_record = [
      [0.0, 0.0, 1.0].pack("#{double_format}3"),
      [1.0, 2.0].pack("#{double_format}2"),
      [integer].pack(integer_format)
    ].join.ljust(1024, "\0")
    names_record = "name".ljust(1024, "\0")
    allow(binary_reader).to receive(:read_record)
      .with(5)
      .and_return(summary_record)
    allow(binary_reader).to receive(:read_record)
      .with(6)
      .and_return(names_record)
    summary_manager = Ephem::IO::SummaryManager.new(
      record_data: record_data,
      binary_reader: binary_reader,
      endianness: endianness
    )

    summary_manager.each_summary.map { |_name, values| values }.first
  end
end
