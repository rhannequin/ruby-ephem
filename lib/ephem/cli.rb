# frozen_string_literal: true

require "optparse"
require "date"

module Ephem
  class CLI
    def self.gregorian_to_julian(date_str)
      date = Date.parse(date_str)

      a = (14 - date.month) / 12
      y = date.year + 4800 - a
      m = date.month + 12 * a - 3

      date.day +
        ((153 * m + 2) / 5) +
        365 * y +
        (y / 4) -
        (y / 100) +
        (y / 400) -
        32045
    end

    def self.start(args)
      if args.empty?
        puts "Usage: ruby-ephem excerpt [options] START_DATE END_DATE INPUT_FILE OUTPUT_FILE"
        puts "For help: ruby-ephem help"
        return
      end

      if args[0] == "help"
        show_help
        return
      end

      if args[0] == "excerpt"
        handle_excerpt(args[1..-1])
        return
      end

      puts "Unknown command: #{args[0]}"
      puts "Available commands: excerpt, help"
    end

    def self.show_help
      puts <<~HELP
        Ruby Ephem - A tool for working with JPL Ephemerides

        Commands:
          excerpt - Create an excerpt of an SPK file
          help    - Show this help message

        Excerpt command:
          ruby-ephem excerpt [options] START_DATE END_DATE INPUT_FILE OUTPUT_FILE

        Options:
          --targets TARGET_IDS  - Comma-separated list of target IDs to include
                                  (default: all targets)

        Example:
          ruby-ephem excerpt --targets 3,10,399 2000-01-01 2030-01-01 de440s.bsp excerpt.bsp

        This will create an excerpt of de440s.bsp containing only the specified
        targets (Earth-Moon barycenter, Sun, Earth) for the period from
        2000-01-01 to 2030-01-01.
      HELP
    end

    # Handle the excerpt command
    def self.handle_excerpt(args)
      # Parse options
      options = {target_ids: nil, debug: false}

      option_parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby-ephem excerpt [options] START_DATE END_DATE INPUT_FILE OUTPUT_FILE"

        opts.on("--targets TARGET_IDS", "Comma-separated list of target IDs to include") do |targets|
          options[:target_ids] = targets.split(",").map(&:strip).map(&:to_i)
        end

        opts.on("--debug", "Enable debug output") do
          options[:debug] = true
        end
      end

      begin
        option_parser.parse!(args)
      rescue OptionParser::InvalidOption => e
        puts e.message
        puts option_parser
        return
      end

      if args.size < 4
        puts "Not enough arguments."
        puts option_parser
        return
      end

      start_date_str = args[0]
      end_date_str = args[1]
      input_file = args[2]
      output_file = args[3]

      unless File.exist?(input_file)
        puts "Error: Input file '#{input_file}' does not exist."
        return
      end

      begin
        start_jd = gregorian_to_julian(start_date_str)
        end_jd = gregorian_to_julian(end_date_str)
      rescue Date::Error => e
        puts "Error parsing dates: #{e.message}"
        puts "Dates should be in YYYY-MM-DD format."
        return
      end

      begin
        puts "Creating excerpt from #{input_file} to #{output_file}..."
        puts "Date range: #{start_date_str} to #{end_date_str} (JD #{start_jd} to #{end_jd})"
        if options[:target_ids]
          puts "Including targets: #{options[:target_ids].join(", ")}"
        else
          puts "Including all targets"
        end

        spk = Ephem::SPK.open(input_file)

        excerpt_spk = spk.excerpt(
          output_path: output_file,
          start_jd: start_jd,
          end_jd: end_jd,
          target_ids: options[:target_ids],
          debug: options[:debug]
        )

        puts "Excerpt created successfully!"
        puts "Original segments: #{spk.segments.size}"
        puts "Excerpt segments: #{excerpt_spk.segments.size}"

        original_size = File.size(input_file)
        excerpt_size = File.size(output_file)
        reduction_percentage =
          ((original_size - excerpt_size) / original_size.to_f * 100).round(2)

        puts "File size reduced by #{reduction_percentage}%"
        puts "Original: #{original_size} bytes"
        puts "Excerpt: #{excerpt_size} bytes"

        spk.close
        excerpt_spk.close
      rescue => e
        puts "Error creating excerpt: #{e.message}"
        puts e.backtrace if options[:debug]
      end
    end
  end
end
