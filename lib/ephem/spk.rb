# frozen_string_literal: true

module Ephem
  # The SPK class represents a SPICE Kernel (SPK) file, which contains ephemeris
  # data for solar system bodies. It manages segments of trajectory data and
  # provides methods to access and manipulate this data.
  #
  # SPK files contain segments of ephemeris data, where each segment represents
  # the motion of one body (target) with respect to another body (center) over
  # a specific time period.
  #
  # @example Opening and using an SPK file
  #   spk = Ephem::SPK.open("de421.bsp")
  #   segment = spk[0, 10]
  #   spk.close
  #
  class SPK
    DATA_TYPE_IDENTIFIER = 5

    attr_reader :segments, :pairs

    # Creates a new SPK instance with the given DAF.
    #
    # @param daf [Ephem::IO::DAF] The DAF (Double precision Array File)
    #   containing SPK data
    # @raise [ArgumentError] If the DAF is nil
    def initialize(daf:)
      raise ArgumentError, "DAF cannot be nil" if daf.nil?

      @daf = daf
      @segments = load_segments
      @pairs = build_pairs
    end

    # Opens an SPK file at the specified path.
    #
    # @param path [String] Path to the SPK file
    # @return [SPK] A new SPK instance
    # @raise [ArgumentError] If the file cannot be accessed due to permissions
    def self.open(path)
      daf = IO::DAF.new(File.open(path, "rb"))
      new(daf: daf)
    rescue Errno::EACCES => e
      raise ArgumentError, "File permission denied: #{path} (#{e.message})"
    end

    # Closes the SPK file and cleans up resources.
    # This method should be called when you're done using the SPK file.
    #
    # @return [void]
    def close
      @daf&.close
      @segments&.each(&:clear_data)
    end

    # Returns a string representation of the SPK file.
    #
    # @return [String] A description of the SPK file and its segments
    def to_s
      <<~DESCRIPTION
        SPK file with #{@segments.size} segments:
        #{@segments.map(&:to_s).join("\n")}
      DESCRIPTION
    end

    # Retrieves the segment for a specific center-target pair.
    #
    # @param center [Integer] NAIF ID of the center body
    # @param target [Integer] NAIF ID of the target body
    # @return [Segments::BaseSegment] The segment containing data for the
    #   specified bodies
    # @raise [KeyError] If no segment is found for the given center-target pair
    def [](center, target)
      @pairs.fetch([center, target]) do
        raise KeyError,
          "No segment found for center: #{center}, target: #{target}"
      end
    end

    # Returns the comments stored in the SPK file.
    #
    # @return [String] The comments from the DAF file
    def comments
      @daf.comments
    end

    # Iterates through all segments in the SPK file.
    #
    # @yield [segment] Gives each segment to the block
    # @yieldparam segment [Segments::BaseSegment] A segment from the SPK file
    # @return [Enumerator] If no block is given
    # @return [void] If a block is given
    def each_segment(&block)
      return enum_for(:each_segment) unless block_given?

      @segments.each(&block)
    end

    private

    def load_segments
      @daf.summaries.map do |source, descriptor|
        build_segment(source: source, descriptor: descriptor)
      end
    end

    def build_pairs
      @segments.to_h do |segment|
        [[segment.center, segment.target], segment]
      end
    end

    def build_segment(source:, descriptor:)
      data_type = descriptor[DATA_TYPE_IDENTIFIER]
      segment_class = SEGMENT_CLASSES.fetch(data_type, Segments::BaseSegment)
      segment_class.new(daf: @daf, source: source, descriptor: descriptor)
    end

    SEGMENT_CLASSES = {}
  end
end
