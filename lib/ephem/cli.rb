# frozen_string_literal: true

require "optparse"
require "date"

module Ephem
  class CLI
    SUCCESS = 0
    FAILURE = 1
    EXCERPT_USAGE = "Usage: ruby-ephem excerpt [options] " \
      "START_DATE END_DATE INPUT_FILE OUTPUT_FILE"
    EXCERPT_ARGUMENT_COUNT = 4
    DATE_FORMAT = /\A([+-]?\d+)-(\d{1,2})-(\d{1,2})\z/

    # Converts a YYYY-MM-DD date to the Julian Date at midnight (00:00) of
    # that day.
    #
    # Dates are read in the proleptic Gregorian calendar, as in ISO 8601, so
    # dates before the 1582 calendar reform are not read as Julian calendar
    # dates.
    #
    # @param date_str [String] Date to convert, such as "2000-01-01"
    # @return [Float] Julian Date at midnight, such as 2451544.5
    # @raise [Date::Error] if the date is not a valid YYYY-MM-DD date
    def self.gregorian_to_julian(date_str)
      match = DATE_FORMAT.match(date_str)
      raise Date::Error, "invalid date: #{date_str}" unless match

      year, month, day = match.captures.map { |part| Integer(part, 10) }
      Date.new(year, month, day, Date::GREGORIAN).ajd.to_f
    end

    # Runs the command given on the command line.
    #
    # @param args [Array<String>] Command line arguments
    # @return [Integer] Exit status, 0 on success and 1 on failure
    def self.start(args)
      command, *command_args = args

      case command
      when nil
        warn EXCERPT_USAGE
        warn "For help: ruby-ephem help"
        FAILURE
      when "help"
        show_help
        SUCCESS
      when "excerpt"
        handle_excerpt(command_args)
      else
        warn "Unknown command: #{command}"
        warn "Available commands: excerpt, help"
        FAILURE
      end
    end

    def self.show_help
      puts <<~HELP
        Ruby Ephem - A tool for working with JPL Ephemerides

        Commands:
          excerpt - Create an excerpt of an SPK or binary PCK kernel
          help    - Show this help message

        Excerpt command:
          ruby-ephem excerpt [options] START_DATE END_DATE INPUT_FILE OUTPUT_FILE

        START_DATE and END_DATE are read in the Gregorian calendar and
        converted to the Julian Date at midnight of that day.

        Options:
          --targets TARGET_IDS  - Comma-separated list of target/body IDs to
                                  include (default: all)

        Examples:
          ruby-ephem excerpt --targets 3,10,399 2000-01-01 2030-01-01 de440s.bsp excerpt.bsp
          ruby-ephem excerpt --targets 31008 2000-01-01 2030-01-01 moon_pa_de440.bpc moon_excerpt.bpc

        The input kernel kind (SPK or binary PCK) is detected automatically and
        the excerpt is written in the same format.
      HELP
    end

    # Handles the excerpt command.
    #
    # @param args [Array<String>] Arguments following the command name
    # @return [Integer] Exit status, 0 on success and 1 on failure
    def self.handle_excerpt(args)
      options = {target_ids: nil, debug: false}
      option_parser = excerpt_option_parser(options)

      begin
        arguments = option_parser.parse(args)
      rescue OptionParser::ParseError => e
        warn e.message
        warn option_parser
        return FAILURE
      end

      if arguments.size != EXCERPT_ARGUMENT_COUNT
        warn "Expected #{EXCERPT_ARGUMENT_COUNT} arguments, " \
          "got #{arguments.size}."
        warn option_parser
        return FAILURE
      end

      start_date_str, end_date_str, input_file, output_file = arguments

      unless File.file?(input_file)
        warn "Error: Input file '#{input_file}' does not exist " \
          "or is not a file."
        return FAILURE
      end

      if File.exist?(output_file) && File.identical?(input_file, output_file)
        warn "Error: Output file must be different from the input file."
        return FAILURE
      end

      begin
        start_jd = gregorian_to_julian(start_date_str)
        end_jd = gregorian_to_julian(end_date_str)
      rescue Date::Error => e
        warn "Error parsing dates: #{e.message}"
        warn "Dates should be in YYYY-MM-DD format."
        return FAILURE
      end

      if start_jd > end_jd
        warn "Error: START_DATE must not be after END_DATE."
        return FAILURE
      end

      create_excerpt(
        input_file: input_file,
        output_file: output_file,
        start_date_str: start_date_str,
        end_date_str: end_date_str,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: options[:target_ids],
        debug: options[:debug]
      )
    end

    def self.excerpt_option_parser(options)
      OptionParser.new do |parser|
        parser.banner = EXCERPT_USAGE

        parser.on(
          "--targets TARGET_IDS",
          "Comma-separated list of target IDs to include"
        ) do |targets|
          options[:target_ids] = parse_target_ids(targets)
        end

        parser.on("--debug", "Enable debug output") do
          options[:debug] = true
        end
      end
    end

    # Parses a comma-separated list of integer target IDs.
    #
    # @param value [String] Value of the --targets option, such as "3,10,399"
    # @return [Array<Integer>] Target IDs
    # @raise [OptionParser::InvalidArgument] if the list is empty or contains
    #   a value that is not an integer
    def self.parse_target_ids(value)
      target_ids = value.split(",", -1).map { |id| Integer(id.strip, 10) }
      raise ArgumentError, "no target IDs" if target_ids.empty?

      target_ids
    rescue ArgumentError
      raise OptionParser::InvalidArgument, value
    end

    def self.create_excerpt(
      input_file:,
      output_file:,
      start_date_str:,
      end_date_str:,
      start_jd:,
      end_jd:,
      target_ids:,
      debug:
    )
      puts "Creating excerpt from #{input_file} to #{output_file}..."
      puts "Date range: #{start_date_str} to #{end_date_str} " \
        "(JD #{start_jd} to #{end_jd})"
      if target_ids
        puts "Including targets: #{target_ids.join(", ")}"
      else
        puts "Including all targets"
      end

      kernel = open_kernel(input_file)
      excerpt_kernel = kernel.excerpt(
        output_path: output_file,
        start_jd: start_jd,
        end_jd: end_jd,
        target_ids: target_ids,
        debug: debug
      )

      puts "Excerpt created successfully!"
      puts "Original segments: #{kernel.segments.size}"
      puts "Excerpt segments: #{excerpt_kernel.segments.size}"
      print_size_reduction(input_file, output_file)

      SUCCESS
    rescue => e
      warn "Error creating excerpt: #{e.message}"
      warn e.backtrace if debug
      FAILURE
    ensure
      excerpt_kernel&.close
      kernel&.close
    end

    def self.print_size_reduction(input_file, output_file)
      original_size = File.size(input_file)
      excerpt_size = File.size(output_file)
      reduction_percentage =
        ((original_size - excerpt_size) / original_size.to_f * 100).round(2)

      puts "File size reduced by #{reduction_percentage}%"
      puts "Original: #{original_size} bytes"
      puts "Excerpt: #{excerpt_size} bytes"
    end

    def self.open_kernel(path)
      file = File.open(path, "rb")
      daf = Ephem::IO::DAF.new(file)

      if daf.file_type == :pck
        Ephem::PCK.new(daf: daf)
      else
        Ephem::SPK.new(daf: daf)
      end
    rescue
      (daf || file)&.close
      raise
    end
  end
end
