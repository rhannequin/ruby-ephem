# frozen_string_literal: true

module Ephem
  # Reads a binary PCK (+DAF/PCK+) orientation kernel: the orientation of one or
  # more body frames over time, expressed as Euler angles.
  class PCK
    # Index of the data type within a PCK summary descriptor
    # ([start, end, body, reference_frame, data_type, start_i, end_i]).
    DATA_TYPE_IDENTIFIER = 4

    attr_reader :daf, :segments

    # @param daf [Ephem::IO::DAF] DAF containing PCK data
    # @raise [ArgumentError] if the DAF is nil
    def initialize(daf:)
      raise ArgumentError, "DAF cannot be nil" if daf.nil?

      @daf = daf
      @segments = load_segments
      @bodies = build_bodies
    end

    # Opens a binary PCK file.
    #
    # @param path [String] Path to the PCK (+.bpc+) file
    # @return [PCK]
    # @raise [ArgumentError] if the file is not a binary PCK or cannot be read
    def self.open(path)
      daf = IO::DAF.new(File.open(path, "rb"))
      unless daf.file_type == :pck
        raise ArgumentError, "#{path} is not a binary PCK (DAF/PCK) file"
      end

      new(daf: daf)
    rescue Errno::EACCES => e
      raise ArgumentError, "File permission denied: #{path} (#{e.message})"
    rescue
      daf&.close
      raise
    end

    # @return [void]
    def close
      @daf&.close
      @segments&.each(&:clear_data)
    end

    # Retrieves the orientation source for a body frame.
    #
    # @param body [Integer] NAIF frame ID of the oriented body
    # @return [Segments::OrientationSegment, Segments::OrientationGroup] a
    #   single segment, or a group routing each query to the covering segment
    #   when the body spans several time intervals
    # @raise [KeyError] if no segment is found for the given body
    def [](body)
      @bodies.fetch(body) do
        raise KeyError, "No orientation segment found for body: #{body}"
      end
    end

    # @return [String] the comments stored in the PCK file
    def comments
      @daf.comments
    end

    # @yieldparam segment [Segments::OrientationSegment]
    # @return [Enumerator] if no block is given
    def each_segment(&block)
      return enum_for(:each_segment) unless block_given?

      @segments.each(&block)
    end

    # @return [String] a description of the PCK file and its segments
    def to_s
      <<~DESCRIPTION
        PCK file with #{@segments.size} segments:
        #{@segments.map(&:to_s).join("\n")}
      DESCRIPTION
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

    def build_bodies
      @segments.group_by(&:body).transform_values do |segments|
        Segments::OrientationGroup.wrap(segments)
      end
    end

    def build_segment(source:, descriptor:)
      data_type = descriptor[DATA_TYPE_IDENTIFIER]
      segment_class = Segments::Registry.lookup(:pck, data_type)
      unless segment_class
        raise UnsupportedError, "Unsupported PCK data type: #{data_type}"
      end

      segment_class.new(daf: @daf, source: source, descriptor: descriptor)
    end
  end
end
