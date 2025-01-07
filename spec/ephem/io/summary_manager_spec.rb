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
        .and_return({next_record: 0, previous_record: 0, n_summaries: 2})

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
        .and_return({next_record: 0, previous_record: 0, n_summaries: 2})

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
        .and_return({next_record: 7, previous_record: 0, n_summaries: 2})

      allow(record_parser).to receive(:parse_summary_control)
        .with(second_record[0, 24])
        .and_return({next_record: 0, previous_record: 5, n_summaries: 1})

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
  end
end
