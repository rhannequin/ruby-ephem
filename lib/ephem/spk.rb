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
  # @example Opening an SPK file with a block, closed automatically
  #   Ephem::SPK.open("de421.bsp") { |spk| spk[0, 10].position_at(2451545.0) }
  #
  class SPK
    TYPES = [
      INPOP = "IMCCE INPOP",
      JPL_DE = "JPL DE"
    ].freeze

    INPOP_REGEXP = /^\s+\d{4}\.\d{5}0+$/
    DE_REGEXP = /^[A-Z]E-(\d{4})LE-\1$/
    DE_FILENAME = "NIO2SPK"

    DATA_TYPE_IDENTIFIER = 5

    attr_reader :daf, :segments, :pairs

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
      @neighbor_links = build_neighbor_links
      @chains = {}
    end

    # Opens an SPK file at the specified path.
    #
    # Without a block, returns the open kernel; the caller must close it.
    # With a block, yields the kernel, closes it when the block returns or
    # raises, and returns the block's value, like +File.open+.
    #
    # @param path [String] Path to the SPK file
    # @yieldparam spk [SPK] the open kernel
    # @return [SPK] the open kernel, if no block is given
    # @return [Object] the block's value, if a block is given
    # @raise [Ephem::FileFormatError] If the file is a binary PCK
    def self.open(path)
      spk = load_kernel(path)
      return spk unless block_given?

      begin
        yield spk
      ensure
        spk.close
      end
    end

    def self.load_kernel(path)
      daf = IO::DAF.new(File.open(path, "rb"))
      if daf.file_type == :pck
        raise FileFormatError,
          "#{path} is a binary PCK file, use Ephem::PCK.open"
      end

      new(daf: daf)
    rescue
      daf&.close
      raise
    end
    private_class_method :load_kernel

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
        #{@segments.join("\n")}
      DESCRIPTION
    end

    # Retrieves the segment for a specific center-target pair.
    #
    # @param center [Integer] NAIF ID of the center body
    # @param target [Integer] NAIF ID of the target body
    # @return [Segments::Segment, Segments::PositionGroup] the position source
    #   for the pair: a single segment, or a group routing each query to the
    #   covering segment when the pair spans several time intervals
    # @raise [KeyError] If no segment is found for the given center-target pair
    def [](center, target)
      @pairs.fetch([center, target]) do
        raise KeyError,
          "No segment found for center: #{center}, target: #{target}"
      end
    end

    # Position of a target body relative to a center body, at the given time.
    #
    # Unlike {#[]}, the pair does not have to be stored in the kernel: the
    # position is chained through the stored pairs that link the two bodies.
    # Earth relative to the Solar System Barycenter is (0 -> 3) + (3 -> 399)
    # in a JPL DE kernel, and the Moon relative to the Earth is
    # (3 -> 301) - (3 -> 399). A pair that is stored is read directly. A
    # body relative to itself is a zero vector, whatever the time.
    #
    # @example Moon relative to the Earth
    #   spk.position_at(target: 301, center: 399, tdb: 2460676.5)
    #
    # @param target [Integer] NAIF ID of the target body
    # @param center [Integer] NAIF ID of the center body
    # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
    # @param tdb2 [Numeric] Optional fractional part of TDB date
    # @return [Core::Vector, Array<Core::Vector>] Position(s) in km
    # @raise [KeyError] If no chain of stored pairs links the two bodies
    # @raise [Ephem::OutOfRangeError] If a pair on the chain does not cover
    #   the time
    def position_at(target:, center:, tdb:, tdb2: 0.0)
      chain(target, center).compute(tdb, tdb2)
    end

    # Position and velocity of a target body relative to a center body, at
    # the given time. See {#position_at} for how the two bodies are linked.
    #
    # @param target [Integer] NAIF ID of the target body
    # @param center [Integer] NAIF ID of the center body
    # @param tdb [Numeric, Array<Numeric>] Time(s) in TDB Julian Date
    # @param tdb2 [Numeric] Optional fractional part of TDB date
    # @return [Core::State, Array<Core::State>] State(s) in km and km/day
    # @raise [KeyError] If no chain of stored pairs links the two bodies
    # @raise [Ephem::OutOfRangeError] If a pair on the chain does not cover
    #   the time
    def state_at(target:, center:, tdb:, tdb2: 0.0)
      chain(target, center).compute_and_differentiate(tdb, tdb2)
    end

    # Type of SPK file to make the difference between JPL DE and IMCCE INPOP
    #
    # @return [String, nil] The type of the SPK file
    def type
      @type ||= if @daf.record_data.internal_filename.match?(INPOP_REGEXP)
        INPOP
      elsif @daf.record_data.internal_filename == DE_FILENAME ||
          segments.first&.source&.match?(DE_REGEXP)
        JPL_DE
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

    def excerpt(output_path:, start_jd:, end_jd:, target_ids: nil, debug: false)
      Excerpt
        .new(self)
        .extract(
          output_path: output_path,
          start_jd: start_jd,
          end_jd: end_jd,
          target_ids: target_ids,
          debug: debug
        )
    end

    private

    def load_segments
      @daf.summaries.map do |source, descriptor|
        build_segment(source: source, descriptor: descriptor)
      end
    end

    def build_pairs
      @segments
        .group_by { |segment| [segment.center, segment.target] }
        .transform_values { |segments| Segments::PositionGroup.wrap(segments) }
    end

    def chain(target, center)
      @chains[[target, center]] ||= begin
        links = path_links(target, center)
        if links.one? && links.first.forward
          links.first.source
        else
          Segments::PositionChain.new(links)
        end
      end
    end

    def path_links(target, center)
      unless @neighbor_links.key?(center) && @neighbor_links.key?(target)
        raise_no_chain(target, center)
      end

      previous_links = {center => nil}
      queue = [center]
      until queue.empty? || previous_links.key?(target)
        body = queue.shift
        @neighbor_links.fetch(body).each do |neighbor, link|
          next if previous_links.key?(neighbor)

          previous_links[neighbor] = [body, link]
          queue << neighbor
        end
      end

      raise_no_chain(target, center) unless previous_links.key?(target)

      links = []
      body = target
      until body == center
        body, link = previous_links.fetch(body)
        links.unshift(link)
      end
      links
    end

    def raise_no_chain(target, center)
      raise KeyError,
        "No chain of segments links center: #{center}, target: #{target}"
    end

    def build_neighbor_links
      neighbors = Hash.new { |hash, body| hash[body] = [] }
      @pairs.each do |(center, target), source|
        neighbors[center] << [
          target, Segments::PositionChain::Link.new(source, true)
        ]
        neighbors[target] << [
          center, Segments::PositionChain::Link.new(source, false)
        ]
      end
      neighbors.default_proc = nil
      neighbors
    end

    def build_segment(source:, descriptor:)
      data_type = descriptor[DATA_TYPE_IDENTIFIER]
      segment_class = Segments::Registry.lookup(
        :spk,
        data_type,
        Segments::BaseSegment
      )
      segment_class.new(daf: @daf, source: source, descriptor: descriptor)
    end
  end
end
