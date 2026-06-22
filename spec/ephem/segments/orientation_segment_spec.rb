# frozen_string_literal: true

RSpec.describe Ephem::Segments::OrientationSegment do
  describe "#angles_at" do
    it "returns an Orientation of the three Euler angles" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      orientation = segment.angles_at(time)

      expect(orientation).to be_a(Ephem::Core::Orientation)
      expect(orientation.phi).to be_within(1e-12).of(1.0)
      expect(orientation.theta).to be_within(1e-12).of(2.0)
      expect(orientation.psi).to be_within(1e-12).of(3.0)
    end

    it "carries no rates" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      expect(segment.angles_at(time).rates?).to be(false)
    end

    it "returns an Orientation per time for an array input" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      orientations = segment.angles_at([time, time + (15.0 / 86400.0)])

      expect(orientations.length).to eq(2)
      expect(orientations).to all(be_a(Ephem::Core::Orientation))
    end

    it "raises OutOfRangeError outside the coverage" do
      segment = create_segment_with_data
      early = Ephem::Core::Constants::Time::J2000_EPOCH - 1.0

      expect { segment.angles_at(early) }
        .to raise_error(Ephem::OutOfRangeError)
    end
  end

  describe "#orientation_at" do
    it "returns an Orientation carrying rates" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      orientation = segment.orientation_at(time)

      expect(orientation.rates?).to be(true)
      expect(orientation.rates.length).to eq(3)
    end
  end

  describe "#matrix_at" do
    it "returns the rotation matrix from the angles" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      expect(segment.matrix_at(time))
        .to eq(segment.angles_at(time).to_matrix)
    end

    it "returns one matrix per time for an array input" do
      segment = create_segment_with_data
      time = Ephem::Core::Constants::Time::J2000_EPOCH

      matrices = segment.matrix_at([time, time + (15.0 / 86400.0)])

      expect(matrices.length).to eq(2)
      expect(matrices).to all(be_an(Array))
    end
  end

  describe "#body and #reference_frame" do
    it "expose the oriented frame and the reference frame" do
      segment = create_segment_with_data

      expect(segment.body).to eq(31008)
      expect(segment.reference_frame).to eq(1)
    end
  end

  describe "#describe" do
    it "describes the orientation by frame IDs" do
      segment = create_segment_with_data

      expect(segment.describe).to include(
        "Type 2 orientation of frame 31008 relative to frame 1"
      )
    end
  end

  describe "#compute" do
    it "directs callers to the orientation methods" do
      segment = create_segment_with_data

      expect { segment.compute(0.0) }.to raise_error(
        NotImplementedError, /angles_at or #orientation_at/
      )
      expect { segment.compute_and_differentiate(0.0) }.to raise_error(
        NotImplementedError, /orientation_at/
      )
    end
  end

  def create_mock_daf
    daf = instance_double(Ephem::IO::DAF)

    allow(daf).to receive(:read_array) do |start_word, end_word|
      if end_word >= 97
        [1, 96, 11, 1]
      else
        [
          0.0,     # midpoint (seconds from J2000)
          43200.0, # radius (half day in seconds)
          1.0, 0.05, 0.0,   # phi coefficients
          2.0, 0.1, 0.0,    # theta coefficients
          3.0, 0.15, 0.0    # psi coefficients
        ][(start_word - 1)..(end_word - 1)]
      end
    end

    allow(daf).to receive(:map_array) do |start_word, end_word|
      daf.read_array(start_word, end_word)
    end

    daf
  end

  def create_segment_with_data
    descriptor = [
      0.0,     # start_second
      86400.0, # end_second
      31008,   # body (MOON_PA_DE440 frame)
      1,       # reference_frame (J2000)
      2,       # data_type
      1,       # start_i
      100      # end_i
    ]

    described_class.new(
      daf: create_mock_daf,
      source: "moon_pa_de440.bpc",
      descriptor: descriptor
    )
  end
end
