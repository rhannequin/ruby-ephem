# frozen_string_literal: true

module Ephem
  class SPK
    # Class representing an SPK file
    attr_reader :segments, :pairs

    def initialize(daf:)
      @daf = daf
      @segments = load_segments
      @pairs = build_pairs
    end

    def self.open(path)
      # Open the file at `path` and return an SPK instance.
      daf = IO::DAF.new(File.open(path, "rb"))
      new(daf: daf)
    end

    def close
      # Use the DAF's close method which will handle the file closing
      # through BinaryReader
      @daf&.close
      @segments&.each(&:clear_data)
    end

    def to_s
      <<~DESCRIPTION
        SPK file with #{@segments.size} segments:
        #{@segments.map(&:to_s).join("\n")}
      DESCRIPTION
    end

    def [](center, target)
      @pairs.fetch([center, target]) do
        raise KeyError,
          "No segment found for center: #{center}, target: #{target}"
      end
    end

    def comments
      @daf.comments
    end

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
      data_type = descriptor[5]
      segment_class = SEGMENT_CLASSES.fetch(data_type, Segments::BaseSegment)
      segment_class.new(daf: @daf, source: source, descriptor: descriptor)
    end

    SEGMENT_CLASSES = {}
  end
end
