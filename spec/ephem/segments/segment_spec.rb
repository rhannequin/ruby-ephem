# frozen_string_literal: true

RSpec.describe Ephem::Segments::Segment do
  describe "#compute" do
    it "returns a vector for a time within range" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      result = segment.compute(time)

      expect(result).to be_a(Ephem::Core::Vector)
      expect(result.x).to be_within(1e-12).of(1.0)
      expect(result.y).to be_within(1e-12).of(2.0)
      expect(result.z).to be_within(1e-12).of(3.0)
    end

    it "raises OutOfRangeError for time before start" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH
      early_time = time - 1.0

      expect { segment.compute(early_time) }.to raise_error(
        Ephem::OutOfRangeError,
        /Time .* is outside the coverage of this segment/
      )
    end

    it "raises OutOfRangeError for time after end" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH
      late_time = time + 2.0

      expect { segment.compute(late_time) }.to raise_error(
        Ephem::OutOfRangeError,
        /Time .* is outside the coverage of this segment/
      )
    end
  end

  describe "#compute_and_differentiate" do
    it "returns position and velocity vectors for time within range" do
      segment = create_segment_with_data
      time = 2451545

      result = segment.compute_and_differentiate(time)

      expect(result).to be_a(Ephem::Core::State)
      expect(result.position).to be_a(Ephem::Core::Vector)
      expect(result.velocity).to be_a(Ephem::Core::Vector)

      expect(result.position.x).to be_within(1e-12).of(1.0)
      expect(result.position.y).to be_within(1e-12).of(2.0)
      expect(result.position.z).to be_within(1e-12).of(3.0)

      expect(result.velocity.x).to be_within(1e-12).of(0.1)
      expect(result.velocity.y).to be_within(1e-12).of(0.2)
      expect(result.velocity.z).to be_within(1e-12).of(0.3)
    end

    it "computes position and velocity for multiple times" do
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      segment = create_segment_with_data
      # Use two times that fall within our test data's interval
      # (±10 seconds from midpoint)
      times = [
        time,
        time + (15.0 / 86400.0)  # 15 seconds later
      ]

      results = segment.compute_and_differentiate(times)

      expect(results).to be_an(Array)
      expect(results.length).to eq(2)
      results.each do |result|
        expect(result).to be_a(Ephem::Core::State)
        expect(result.position).to be_a(Ephem::Core::Vector)
        expect(result.velocity).to be_a(Ephem::Core::Vector)
      end
    end
  end

  describe "#describe" do
    it "returns a human-readable description of the segment" do
      segment = create_segment_with_data

      description = segment.describe

      expect(description).to include("Earth-moon Barycenter (3)")
      expect(description).to include("Solar System Barycenter (0)")
      expect(description).to include("Type 2")
      expect(description).to match(/\d{4}-\d{2}-\d{2}\.{2}\d{4}-\d{2}-\d{2}/)
    end

    it "includes additional details when verbose is true" do
      segment = create_segment_with_data

      description = segment.describe(verbose: true)

      expect(description).to include("frame=1")
      expect(description).to include("source=DE440.bsp")
    end
  end

  describe "#clear_data" do
    it "clears cached data" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      # Track map_array calls
      load_count = 0
      allow(segment.daf).to receive(:map_array) do |start_word, end_word|
        load_count += 1
        # Return original test data
        [
          0.0, 43200.0,
          1.0, 0.05, 0.0,
          2.0, 0.1, 0.0,
          3.0, 0.15, 0.0
        ][(start_word - 1)..(end_word - 1)]
      end

      # First computation loads data
      segment.compute(time)
      initial_loads = load_count

      # Second computation should use cache
      segment.compute(time)
      expect(load_count).to eq(initial_loads)

      # After clearing, computation should load data again
      segment.clear_data
      segment.compute(time)
      expect(load_count).to be > initial_loads
    end
  end

  def create_mock_daf
    # Create a double for DAF that handles both coefficient data and metadata
    daf = instance_double(Ephem::IO::DAF)

    # Allow read_array and map_array to handle different ranges of the data
    allow(daf).to receive(:read_array) do |start_word, end_word|
      if end_word >= 97  # Reading metadata from end of segment
        # Metadata must match our actual data structure:
        # - start_index = 1
        # - end_index = last coefficient
        # - record_size = 11 (midpoint + radius + 9 coefficients)
        # - segment_count = 1 (one record)
        [1, 96, 11, 1]
      else
        # Return coefficient data for the segment:
        # We need 3 coefficients per component (x,y,z) for proper Chebyshev evaluation
        [
          0.0,     # midpoint (seconds from J2000)
          43200.0, # radius (half day in seconds)

          # x coefficients
          1.0,     # constant term
          0.05,    # linear term (0.1/2 since derivative doubles it)
          0.0,     # quadratic term

          # y coefficients
          2.0,     # constant term
          0.1,     # linear term (0.2/2)
          0.0,     # quadratic term

          # z coefficients
          3.0,     # constant term
          0.15,    # linear term (0.3/2)
          0.0      # quadratic term
        ][(start_word - 1)..(end_word - 1)]
      end
    end

    # map_array is an alias for read_array
    allow(daf).to receive(:map_array) do |start_word, end_word|
      daf.read_array(start_word, end_word)
    end

    daf
  end

  def create_segment_with_data
    daf = create_mock_daf
    descriptor = [
      0.0,     # start_second
      86400.0, # end_second
      3,       # target (Earth-moon Barycenter)
      0,       # center (Solar System Barycenter)
      1,       # frame
      2,       # data_type (position only)
      1,       # start_i
      100      # end_i
    ]

    described_class.new(
      daf: daf,
      source: "DE440.bsp",
      descriptor: descriptor
    )
  end
end
