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

    it "pairs each time with its own position and velocity" do
      first_time = Ephem::Core::Constants::Time::J2000_EPOCH
      second_time = first_time + (15.0 / 86400.0)
      segment = create_segment_with_data

      array_results =
        segment.compute_and_differentiate([first_time, second_time])
      first_scalar = segment.compute_and_differentiate(first_time)
      second_scalar = segment.compute_and_differentiate(second_time)

      expect(array_results[0].to_arrays).to eq(first_scalar.to_arrays)
      expect(array_results[1].to_arrays).to eq(second_scalar.to_arrays)
    end
  end

  describe "type 3 segments" do
    it "evaluates the position from the position coefficients" do
      segment = create_type3_segment
      quarter_day_later = Ephem::Core::Constants::Time::J2000_EPOCH + 0.25

      position = segment.position_at(quarter_day_later)

      expect(position.x).to be_within(1e-12).of(1.0 + 0.05 * 0.5)
      expect(position.y).to be_within(1e-12).of(2.0 + 0.1 * 0.5)
      expect(position.z).to be_within(1e-12).of(3.0 + 0.15 * 0.5)
    end

    it "evaluates the velocity from the stored velocity coefficients" do
      segment = create_type3_segment
      quarter_day_later = Ephem::Core::Constants::Time::J2000_EPOCH + 0.25
      seconds_per_day = Ephem::Core::Constants::Time::SECONDS_PER_DAY

      state = segment.state_at(quarter_day_later)

      expect(state.velocity.x)
        .to be_within(1e-9).of((2.0e-5 + 1.0e-6 * 0.5) * seconds_per_day)
      expect(state.velocity.y)
        .to be_within(1e-9).of((3.0e-5 + 2.0e-6 * 0.5) * seconds_per_day)
      expect(state.velocity.z)
        .to be_within(1e-9).of((4.0e-5 + 3.0e-6 * 0.5) * seconds_per_day)
    end

    it "reads each record's own velocity coefficients" do
      segment = create_type3_segment
      one_day_later = Ephem::Core::Constants::Time::J2000_EPOCH + 1.0
      seconds_per_day = Ephem::Core::Constants::Time::SECONDS_PER_DAY

      state = segment.state_at(one_day_later)

      expect(state.position.to_a).to eq([10.0, 20.0, 30.0])
      expect(state.velocity.x).to be_within(1e-9).of(5.0e-5 * seconds_per_day)
      expect(state.velocity.y).to be_within(1e-9).of(6.0e-5 * seconds_per_day)
      expect(state.velocity.z).to be_within(1e-9).of(7.0e-5 * seconds_per_day)
    end

    it "returns the same states for array and scalar times" do
      segment = create_type3_segment
      first_time = Ephem::Core::Constants::Time::J2000_EPOCH
      second_time = first_time + 0.25

      array_states = segment.state_at([first_time, second_time])

      expect(array_states.map(&:to_arrays)).to eq(
        [
          segment.state_at(first_time).to_arrays,
          segment.state_at(second_time).to_arrays
        ]
      )
    end

    it "reloads the velocity coefficients after clearing data" do
      segment = create_type3_segment
      time = Ephem::Core::Constants::Time::J2000_EPOCH
      state_before = segment.state_at(time).to_arrays

      segment.clear_data
      state_after = segment.state_at(time).to_arrays

      expect(state_after).to eq(state_before)
    end
  end

  describe "#describe" do
    it "returns a human-readable description of the segment" do
      segment = create_segment_with_data

      description = segment.describe

      expect(description).to include("Earth-Moon Barycenter (3)")
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

  describe "unsupported data types" do
    it "raises UnsupportedError when computing" do
      segment = create_segment_with_data(data_type: 5)
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      expect { segment.compute(time) }
        .to raise_error(Ephem::UnsupportedError, /SPK data type: 5/)
    end
  end

  describe "#clear_data" do
    it "clears cached data" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      segment.compute(time)
      segment.compute(time)
      segment.clear_data
      segment.compute(time)

      expect(segment.daf)
        .to have_received(:read_array).with(1, 96).twice
    end
  end

  def create_mock_daf
    # Create a double for DAF that handles both coefficient data and metadata
    daf = instance_double(Ephem::IO::DAF)

    # Allow read_array to handle different ranges of the data
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

    daf
  end

  def type3_words
    first_record = [
      0.0, 43200.0,
      1.0, 0.05,
      2.0, 0.1,
      3.0, 0.15,
      2.0e-5, 1.0e-6,
      3.0e-5, 2.0e-6,
      4.0e-5, 3.0e-6
    ]
    second_record = [
      86400.0, 43200.0,
      10.0, 0.5,
      20.0, 1.0,
      30.0, 1.5,
      5.0e-5, 4.0e-6,
      6.0e-5, 5.0e-6,
      7.0e-5, 6.0e-6
    ]
    metadata = [-43200.0, 86400.0, first_record.size.to_f, 2.0]
    first_record + second_record + metadata
  end

  def create_type3_segment
    words = type3_words
    daf = instance_double(Ephem::IO::DAF)
    allow(daf).to receive(:read_array) do |start_word, end_word|
      words[(start_word - 1)..(end_word - 1)]
    end
    descriptor = [-43200.0, 129600.0, 3, 0, 1, 3, 1, words.size]

    described_class.new(daf: daf, source: "type3.bsp", descriptor: descriptor)
  end

  def create_segment_with_data(data_type: 2)
    daf = create_mock_daf
    descriptor = [
      0.0,     # start_second
      86400.0, # end_second
      3,       # target (Earth-Moon Barycenter)
      0,       # center (Solar System Barycenter)
      1,       # frame
      data_type,
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
