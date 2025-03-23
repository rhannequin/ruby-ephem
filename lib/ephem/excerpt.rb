# frozen_string_literal: true

module Ephem
  # The Excerpt class creates SPK file excerpts with reduced time spans and
  # target bodies. This is useful for creating smaller files that focus only on
  # the data needed for specific applications.
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
    RECORD_SIZE = 1024

    # @param spk [Ephem::SPK] The SPK object to create an excerpt from
    def initialize(spk)
      @spk = spk
      @daf = spk.instance_variable_get(:@daf)
      @binary_reader = @daf.instance_variable_get(:@binary_reader)
    end

    # Creates an excerpt of the SPK file
    #
    # @param output_path [String] Path where the excerpt will be written
    # @param start_jd [Float] Start time as Julian Date
    # @param end_jd [Float] End time as Julian Date
    # @param target_ids [Array<Integer>, nil] Optional list of target IDs to
    #   include
    # @param debug [Boolean] Whether to print debug information
    #
    # @return [Ephem::SPK] A new SPK instance for the excerpt file
    def extract(output_path:, start_jd:, end_jd:, target_ids: nil, debug: false)
      start_seconds = seconds_since_j2000(start_jd)
      end_seconds = seconds_since_j2000(end_jd)
      output_file = File.open(output_path, "wb+")
      copy_file_header(output_file)
      initialize_summary_section(output_file)
      writer = create_daf_writer(output_file, debug)
      process_segments(writer, start_seconds, end_seconds, target_ids, debug)
      output_file.close

      SPK.open(output_path)
    end

    private

    def seconds_since_j2000(jd)
      (jd - J2000_EPOCH) * S_PER_DAY
    end

    def copy_file_header(output_file)
      # Get the first record number of summaries from original DAF
      fward = @daf.record_data.forward_record

      # Copy file record and comments
      (1...fward).each do |n|
        data = @binary_reader.read_record(n)
        output_file.write(data)
      end
    end

    def initialize_summary_section(output_file)
      summary_data = "\0".ljust(RECORD_SIZE, "\0")
      name_data = " ".ljust(RECORD_SIZE, "\0")
      output_file.write(summary_data)
      output_file.write(name_data)
    end

    def create_daf_writer(output_file, debug)
      writer = DAFWriter.new(output_file, debug)
      fward = @daf.record_data.forward_record
      writer.fward = writer.bward = fward
      writer.free = (fward + 1) * (RECORD_SIZE / 8) + 1
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

      # Read the metadata from the end of the array
      init, intlen, rsize, n = @daf.read_array(end_pos - 3, end_pos)
      rsize = rsize.to_i

      if debug
        puts "  Metadata: init=#{init}, intlen=#{intlen}, rsize=#{rsize}, n=#{n}"
      end

      # Calculate which portion of the data to extract based on the date range
      i = clip(0, n, ((start_seconds - init) / intlen)).to_i
      j = clip(0, n, ((end_seconds - init) / intlen + 1)).to_i

      puts "  Date range: i=#{i}, j=#{j} out of n=#{n}" if debug

      # Skip if no overlap with requested date range
      if i == j
        if debug
          puts "Segment #{segment_index} (#{name}):"
          puts "No overlap with requested date range"
        end

        return false
      end

      # Update initial time and number of records
      init += i * intlen
      n = j - i

      puts "  New metadata: init=#{init}, n=#{n}" if debug

      # Extract the relevant portion of the data
      extra = 4  # Enough space for the metadata: [init intlen rsize n]
      excerpt_start = start_pos + rsize * i
      excerpt_end = start_pos + rsize * j + extra - 1

      puts "  Reading array from #{excerpt_start} to #{excerpt_end}" if debug

      excerpt = @daf.read_array(excerpt_start, excerpt_end)

      puts "  Read #{excerpt.length} values" if debug

      # Update the metadata in the excerpt
      excerpt[-4..-1] = [init, intlen, rsize, n]

      new_values = if values.length >= 2
        [init, init + n * intlen] + values[2...-2]
      else
        [init, init + n * intlen]
      end

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
        puts "Included in excerpt (#{i} to #{j} of #{n})"
      end

      true
    rescue => e
      puts "Error processing segment #{segment_index} (#{name}): #{e.message}"
      puts e.backtrace.join("\n") if debug
      false
    end

    # Clips a value between lower and upper bounds
    def clip(lower, upper, n)
      n.clamp(lower, upper)
    end

    # Helper class for writing DAF files
    # This class handles the low-level details of DAF file format
    class DAFWriter
      attr_reader :file
      attr_accessor :fward,
        :bward,
        :free,
        :endianness,
        :double_format,
        :int_format,
        :nd,
        :ni,
        :summary_format,
        :summary_control_format,
        :summary_length,
        :summary_step,
        :summaries_per_record

      def initialize(file, debug = false)
        @file = file
        @debug = debug
        @mutex = Mutex.new
      end

      def setup_formats(nd, ni)
        @nd = nd
        @ni = ni

        # Double is always 8 bytes, int is always 4 bytes
        double_size = 8
        int_size = 4

        # Set formats based on endianness
        if @endianness == :little
          @double_format = "E"  # Little-endian double
          @int_format = "l"     # Little-endian signed long (32-bit)
        else
          @double_format = "G"  # Big-endian double
          @int_format = "l>"    # Big-endian signed long (32-bit)
        end

        # Create formats for summary structures
        @summary_control_format =
          "#{@double_format}#{@double_format}#{@double_format}"
        @summary_format = @double_format.to_s * @nd + @int_format.to_s * @ni

        # Calculate segment summary sizes
        @summary_length = double_size * @nd + int_size * @ni

        # Pad to 8 bytes
        @summary_step = @summary_length + (-@summary_length % 8)

        @summaries_per_record = (RECORD_SIZE - 8 * 3) / @summary_step
      end

      def write_file_record
        @file.seek(0)
        data = @file.read(RECORD_SIZE)

        # Update pointers directly in the data buffer
        fward_pos = 76
        bward_pos = 80
        free_pos = 84

        if @endianness == :little
          data[fward_pos, 4] = [@fward].pack("l")
          data[bward_pos, 4] = [@bward].pack("l")
          data[free_pos, 4] = [@free].pack("l")
        else
          data[fward_pos, 4] = [@fward].pack("N")
          data[bward_pos, 4] = [@bward].pack("N")
          data[free_pos, 4] = [@free].pack("N")
        end

        # Write the updated record back to the file
        @file.seek(0)
        @file.write(data)
      end

      def read_record(n)
        @mutex.synchronize do
          @file.seek(n * RECORD_SIZE - RECORD_SIZE)
          @file.read(RECORD_SIZE)
        end
      end

      def write_record(n, data)
        @mutex.synchronize do
          @file.seek(n * RECORD_SIZE - RECORD_SIZE)
          @file.write(data)
        end
      end

      def add_array(name, values, array)
        record_number = @bward
        data = read_record(record_number).dup

        control_data = data[0, 24].unpack(@summary_control_format)
        next_record = control_data[0].to_i
        previous_record = control_data[1].to_i
        n_summaries = control_data[2].to_i

        if n_summaries < @summaries_per_record
          # Add to the existing record
          summary_record = record_number
          data[0, 24] = [next_record, previous_record, n_summaries + 1]
            .pack(@summary_control_format)
          write_record(summary_record, data)
        else
          # Create a new record
          summary_record = ((@free - 1) * 8 + 1023) / 1024 + 1
          name_record = summary_record + 1
          free_record = summary_record + 2

          data[0, 24] = [summary_record, previous_record, n_summaries]
            .pack(@summary_control_format)
          write_record(record_number, data)

          n_summaries = 0
          summaries = [0, record_number, 1]
            .pack(@summary_control_format)
            .ljust(RECORD_SIZE, "\0")
          names = " ".ljust(RECORD_SIZE, "\0")
          write_record(summary_record, summaries)
          write_record(name_record, names)

          @bward = summary_record
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

        # Using values up to nd+ni-2, then adding start_word and end_word
        new_values = values[0, @nd + @ni - 2] + [start_word, end_word]

        base = RECORD_SIZE * (summary_record - 1)
        offset = n_summaries * @summary_step
        @file.seek(base + 24 + offset)  # 24 is summary_control_struct size
        @file.write(new_values.pack(@summary_format))
        @file.seek(base + RECORD_SIZE + offset)
        @file.write(name[0, @summary_length].ljust(@summary_step, " "))
      end
    end
  end
end
