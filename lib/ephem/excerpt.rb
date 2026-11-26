# frozen_string_literal: true

require "securerandom"

module Ephem
  # The Excerpt class creates DAF excerpts (SPK or binary PCK) with reduced time
  # spans and bodies. This is useful for creating smaller files that focus only
  # on the data needed for specific applications.
  #
  # @example Create an excerpt with specific time range and bodies
  #   spk = Ephem::SPK.open("de421.bsp")
  #   excerpt = Ephem::Excerpt.new(spk).extract(
  #     output_path: "excerpt.bsp",
  #     start_jd: 2458849.5,           # January 1, 2020
  #     end_jd: 2459580.5,             # December 31, 2021
  #     target_ids: [3, 10, 301, 399]  # Earth-Moon, Sun, Moon, Earth
  #   )
  class Excerpt
    # Constants for time calculations
    S_PER_DAY = Core::Constants::Time::SECONDS_PER_DAY
    J2000_EPOCH = Core::Constants::Time::J2000_EPOCH
    RECORD_SIZE = IO::BinaryReader::RECORD_SIZE
    SUPPORTED_DATA_TYPES = {spk: [2, 3], pck: [2]}.freeze
    DATA_TYPE_INDEXES = {
      spk: SPK::DATA_TYPE_IDENTIFIER,
      pck: PCK::DATA_TYPE_IDENTIFIER
    }.freeze

    # @param kernel [Ephem::SPK, Ephem::PCK] The kernel to excerpt from
    def initialize(kernel)
      @kernel = kernel
      @daf = kernel.daf
      @binary_reader = @daf.binary_reader
    end

    # Creates an excerpt of the SPK file
    #
    # @param output_path [String] Path where the excerpt will be written
    # @param start_jd [Float] Start time as Julian Date
    # @param end_jd [Float] End time as Julian Date
    # @param target_ids [Array<Integer>, nil] Optional list of target/body IDs
    #   to include
    # @param debug [Boolean] Whether to print debug information
    #
    # @return [Ephem::SPK, Ephem::PCK] A new instance for the excerpt file,
    #   matching the source kernel kind
    def extract(output_path:, start_jd:, end_jd:, target_ids: nil, debug: false)
      start_seconds = seconds_since_j2000(start_jd)
      end_seconds = seconds_since_j2000(end_jd)
      write_excerpt(output_path, start_seconds, end_seconds, target_ids, debug)

      reopen(output_path)
    end

    private

    def write_excerpt(
      output_path,
      start_seconds,
      end_seconds,
      target_ids,
      debug
    )
      temp_file = File.open(
        "#{output_path}.#{SecureRandom.hex(8)}.tmp",
        File::RDWR | File::CREAT | File::EXCL | File::BINARY,
        0o666
      )
      copy_file_header(temp_file)
      initialize_summary_section(temp_file)
      writer = create_daf_writer(temp_file)
      process_segments(writer, start_seconds, end_seconds, target_ids, debug)
      temp_file.close
      File.rename(temp_file.path, output_path)
      temp_file = nil
    ensure
      discard(temp_file) if temp_file
    end

    def discard(file)
      file.close
      File.unlink(file.path)
    rescue SystemCallError
      nil
    end

    def reopen(path)
      (@daf.file_type == :pck) ? PCK.open(path) : SPK.open(path)
    end

    def seconds_since_j2000(julian_date)
      (julian_date - J2000_EPOCH) * S_PER_DAY
    end

    def copy_file_header(output_file)
      first_summary_record = @daf.record_data.forward_record

      # Copy file record and comments
      (1...first_summary_record).each do |record_number|
        data = @binary_reader.read_record(record_number)
        output_file.write(data)
      end
    end

    def initialize_summary_section(output_file)
      summary_data = "\0".ljust(RECORD_SIZE, "\0")
      name_data = " ".ljust(RECORD_SIZE, "\0")
      output_file.write(summary_data)
      output_file.write(name_data)
    end

    def create_daf_writer(output_file)
      writer = DAFWriter.new(output_file)
      first_summary_record = @daf.record_data.forward_record
      writer.forward_record = first_summary_record
      writer.backward_record = first_summary_record
      writer.free = (first_summary_record + 1) * (RECORD_SIZE / 8) + 1
      writer.endianness = @daf.endianness
      writer.setup_formats(
        @daf.record_data.double_count,
        @daf.record_data.integer_count
      )
      writer.write_file_record

      writer
    end

    def process_segments(writer, start_seconds, end_seconds, target_ids, debug)
      segments_processed = 0
      segments_included = 0

      # Get all summaries from the original DAF
      @daf.summaries.each do |name, values|
        segments_processed += 1

        # Filter by target ID if specified
        if target_ids && !target_ids.empty?
          # The target ID is at index 2 in the summary values
          target_id = values[2].to_i

          unless target_ids.include?(target_id)
            if debug
              puts "Segment #{segments_processed} (#{name}):"
              puts "Target ID #{target_id} not in requested list, skipping"
            end

            next
          end
        end

        # Extract segment data
        if extract_segment(
          writer,
          name,
          values,
          start_seconds,
          end_seconds,
          segments_processed,
          debug
        )
          segments_included += 1
        end
      end

      if debug
        puts "Summary:"
        puts "Processed #{segments_processed} segments,"
        puts "included #{segments_included} in the excerpt"
      end
    end

    def extract_segment(
      writer,
      name,
      values,
      start_seconds,
      end_seconds,
      segment_index,
      debug
    )
      # Get start and end positions of the segment in the file
      start_pos, end_pos = values[-2], values[-1]

      if debug
        puts "Processing segment #{segment_index} (#{name}):"
        puts "start=#{start_pos}, end=#{end_pos}"
      end

      ensure_supported_data_type(name, values)

      # Read the metadata from the end of the array
      initial_epoch, interval_length, record_length, record_count =
        @daf.read_array(end_pos - 3, end_pos)
      record_length = record_length.to_i

      if debug
        puts "  Metadata: init=#{initial_epoch}, " \
          "intlen=#{interval_length}, rsize=#{record_length}, " \
          "n=#{record_count}"
      end

      first_record = ((start_seconds - initial_epoch) / interval_length)
        .clamp(0, record_count).to_i
      end_record = ((end_seconds - initial_epoch) / interval_length + 1)
        .clamp(0, record_count).to_i

      if debug
        puts "  Date range: records #{first_record} to #{end_record} " \
          "out of #{record_count}"
      end

      # Skip if no overlap with requested date range
      if first_record == end_record
        if debug
          puts "Segment #{segment_index} (#{name}):"
          puts "No overlap with requested date range"
        end

        return false
      end

      initial_epoch += first_record * interval_length
      record_count = end_record - first_record

      if debug
        puts "  New metadata: init=#{initial_epoch}, n=#{record_count}"
      end

      metadata_size = 4
      excerpt_start = start_pos + record_length * first_record
      excerpt_end = start_pos + record_length * end_record + metadata_size - 1

      puts "  Reading array from #{excerpt_start} to #{excerpt_end}" if debug

      excerpt = @daf.read_array(excerpt_start, excerpt_end)

      puts "  Read #{excerpt.length} values" if debug

      excerpt[-4..-1] =
        [initial_epoch, interval_length, record_length, record_count]

      new_values = [
        initial_epoch,
        initial_epoch + record_count * interval_length
      ] + values[2...-2]

      puts "  New values: #{new_values.inspect}" if debug

      # Add the extracted array to the output file
      # Modify the name to indicate it's an excerpt (X prefix)
      writer.add_array(
        "X#{name[1..]}".force_encoding("ASCII-8BIT"),
        new_values,
        excerpt
      )

      if debug
        puts "Segment #{segment_index} (#{name}):"
        puts "Included in excerpt " \
          "(#{first_record} to #{end_record} of #{record_count})"
      end

      true
    end

    def ensure_supported_data_type(name, values)
      file_type = (@daf.file_type == :pck) ? :pck : :spk
      data_type = values[DATA_TYPE_INDEXES.fetch(file_type)].to_i
      return if SUPPORTED_DATA_TYPES.fetch(file_type).include?(data_type)

      raise UnsupportedError,
        "Cannot excerpt #{file_type.upcase} segment #{name.strip.inspect}: " \
        "data type #{data_type} is not supported"
    end

    # Helper class for writing DAF files
    # This class handles the low-level details of DAF file format
    class DAFWriter
      attr_reader :summary_format
      attr_writer :forward_record, :backward_record, :free, :endianness

      def initialize(file)
        @file = file
      end

      def setup_formats(double_count, integer_count)
        @double_count = double_count
        @integer_count = integer_count

        # Double is always 8 bytes, int is always 4 bytes
        double_size = 8
        int_size = 4

        # Set formats based on endianness
        if @endianness == :little
          @double_format = "E"  # Little-endian double
          @int_format = "l<"    # Little-endian signed long (32-bit)
        else
          @double_format = "G"  # Big-endian double
          @int_format = "l>"    # Big-endian signed long (32-bit)
        end

        # Create formats for summary structures
        @summary_control_format =
          "#{@double_format}#{@double_format}#{@double_format}"
        @summary_format = @double_format.to_s * @double_count +
          @int_format.to_s * @integer_count

        # Calculate segment summary sizes
        @summary_length =
          double_size * @double_count + int_size * @integer_count

        # Pad to 8 bytes
        @summary_step = @summary_length + (-@summary_length % 8)

        @summaries_per_record = (RECORD_SIZE - 8 * 3) / @summary_step
      end

      def write_file_record
        @file.seek(0)
        data = @file.read(RECORD_SIZE)

        # Update pointers directly in the data buffer
        forward_position = 76
        backward_position = 80
        free_position = 84

        int_format = (@endianness == :little) ? "l<" : "l>"
        data[forward_position, 4] = [@forward_record].pack(int_format)
        data[backward_position, 4] = [@backward_record].pack(int_format)
        data[free_position, 4] = [@free].pack(int_format)

        # Write the updated record back to the file
        @file.seek(0)
        @file.write(data)
      end

      def read_record(record_number)
        @file.seek((record_number - 1) * RECORD_SIZE)
        @file.read(RECORD_SIZE)
      end

      def write_record(record_number, data)
        @file.seek((record_number - 1) * RECORD_SIZE)
        @file.write(data)
      end

      def add_array(name, values, array)
        record_number = @backward_record
        data = read_record(record_number).dup

        control_data = data[0, 24].unpack(@summary_control_format)
        next_record = control_data[0].to_i
        previous_record = control_data[1].to_i
        summary_count = control_data[2].to_i

        if summary_count < @summaries_per_record
          # Add to the existing record
          summary_record = record_number
          data[0, 24] = [next_record, previous_record, summary_count + 1]
            .pack(@summary_control_format)
          write_record(summary_record, data)
        else
          # Create a new record
          summary_record = ((@free - 1) * 8 + 1023) / 1024 + 1
          name_record = summary_record + 1
          free_record = summary_record + 2

          data[0, 24] = [summary_record, previous_record, summary_count]
            .pack(@summary_control_format)
          write_record(record_number, data)

          summary_count = 0
          summaries = [0, record_number, 1]
            .pack(@summary_control_format)
            .ljust(RECORD_SIZE, "\0")
          names = " ".ljust(RECORD_SIZE, "\0")
          write_record(summary_record, summaries)
          write_record(name_record, names)

          @backward_record = summary_record
          @free = (free_record - 1) * RECORD_SIZE / 8 + 1
        end

        # Convert array to binary data
        array_data = array.pack("#{@double_format}*")

        start_word = @free
        @file.seek((start_word - 1) * 8)
        @file.write(array_data)
        end_word = @file.tell / 8

        @free = end_word + 1
        write_file_record

        new_values =
          values[0, @double_count + @integer_count - 2] + [start_word, end_word]

        base = RECORD_SIZE * (summary_record - 1)
        offset = summary_count * @summary_step
        @file.seek(base + 24 + offset)  # 24 is summary_control_struct size
        @file.write(new_values.pack(@summary_format))
        @file.seek(base + RECORD_SIZE + offset)
        @file.write(name[0, @summary_length].ljust(@summary_step, " "))
      end
    end
  end
end
