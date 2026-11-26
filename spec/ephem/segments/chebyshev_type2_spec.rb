# frozen_string_literal: true

# Minimal host that mixes in the module and exposes the state its methods
# read, so the shared evaluation machinery can be exercised on its own.
class ChebyshevType2TestHost
  include Ephem::Segments::ChebyshevType2

  attr_reader :midpoints, :radii, :coefficients

  def initialize(component_count: 3, midpoints: nil, radii: nil,
    coefficients: nil)
    super()
    @component_count = component_count
    @midpoints = midpoints
    @radii = radii
    @coefficients = coefficients
    @start_jd = 2451545.0
    @end_jd = 2451546.0
  end

  def label
    "test segment"
  end

  private

  attr_reader :component_count
end

RSpec.describe Ephem::Segments::ChebyshevType2 do
  describe "#time_to_seconds" do
    it "returns zero at the J2000 epoch" do
      host = build_host

      expect(host.send(:time_to_seconds, 2451545.0, 0.0)).to eq(0.0)
    end

    it "scales whole days to seconds past J2000" do
      host = build_host

      expect(host.send(:time_to_seconds, 2451546.0, 0.0)).to eq(86400.0)
    end

    it "folds the fractional offset into the result" do
      host = build_host

      expect(host.send(:time_to_seconds, 2451545.0, 0.5)).to eq(43200.0)
    end
  end

  describe "#convert_to_seconds" do
    it "converts a single time" do
      host = build_host

      expect(host.send(:convert_to_seconds, 2451546.0, 0.0)).to eq(86400.0)
    end

    it "converts each element of an array of times" do
      host = build_host

      result = host.send(:convert_to_seconds, [2451545.0, 2451546.0], 0.0)

      expect(result).to eq([0.0, 86400.0])
    end
  end

  describe "#find_interval" do
    it "selects the interval whose window covers the time" do
      host = build_search_host

      expect(host.send(:find_interval, 100.0)).to eq(0)
      expect(host.send(:find_interval, 300.0)).to eq(1)
    end

    it "treats both ends of an interval window as covered" do
      host = build_search_host

      expect(host.send(:find_interval, 90.0)).to eq(0)
      expect(host.send(:find_interval, 110.0)).to eq(0)
    end

    it "still returns the right interval after caching a previous one" do
      host = build_search_host

      host.send(:find_interval, 105.0)

      expect(host.send(:find_interval, 105.0)).to eq(0)
      expect(host.send(:find_interval, 300.0)).to eq(1)
    end

    it "returns the cached interval it checked if the cache changes" do
      host = build_search_host
      host.send(:find_interval, 105.0)
      overwrite_cache_after_check(host, other_interval: 1)

      expect(host.send(:find_interval, 105.0)).to eq(0)
      expect(host).to have_received(:time_in_interval?)
    end

    it "raises when the time falls in a gap between intervals" do
      host = build_search_host

      expect { host.send(:find_interval, 200.0) }
        .to raise_error(Ephem::OutOfRangeError)
    end

    it "raises when the time is before the first interval" do
      host = build_search_host

      expect { host.send(:find_interval, 50.0) }
        .to raise_error(Ephem::OutOfRangeError)
    end

    it "raises when the time is after the last interval" do
      host = build_search_host

      expect { host.send(:find_interval, 350.0) }
        .to raise_error(Ephem::OutOfRangeError)
    end

    it "reports the uncovered time as a Julian Date" do
      host = build_search_host

      expect { host.send(:find_interval, 43200.0) }.to raise_error(
        Ephem::OutOfRangeError,
        /\AJD 2451545.5 \(2000-01-02\) is outside the coverage of test/
      ) { |error| expect(error.out_of_range_times).to eq([2451545.5]) }
    end
  end

  describe "#request_out_of_range_error" do
    it "lists the uncovered times of the request" do
      host = build_search_host
      original_error = Ephem::OutOfRangeError.new("original", [])

      error = host.send(
        :request_out_of_range_error, original_error, 2451546.0, 0.0
      )

      expect(error.out_of_range_times).to eq([2451546.0])
    end

    it "keeps the original error when every time is covered" do
      host = build_search_host
      original_error = Ephem::OutOfRangeError.new("original", [])
      covered = 2451545.0 + 100.0 / 86400.0

      error = host.send(
        :request_out_of_range_error, original_error, covered, 0.0
      )

      expect(error).to be(original_error)
    end
  end

  describe "#uncovered_times" do
    it "keeps the times no interval covers, with their tdb2 fraction" do
      host = build_search_host
      seconds_per_day = Ephem::Core::Constants::Time::SECONDS_PER_DAY
      in_gap = 2451545.0 + 200.0 / seconds_per_day
      covered = 2451545.0 + 100.0 / seconds_per_day
      after_last = 2451545.0 + 400.0 / seconds_per_day

      times = [in_gap, covered, after_last]

      uncovered = host.send(:uncovered_times, times, 0.0)

      expect(uncovered).to eq([in_gap, after_last])
    end

    it "accepts a single time" do
      host = build_search_host

      expect(host.send(:uncovered_times, 2451545.0, 0.25))
        .to eq([2451545.25])
    end
  end

  describe "#time_in_interval?" do
    it "is true on the inclusive bounds of the window" do
      host = build_normalized_host

      expect(host.send(:time_in_interval?, 90.0, 0)).to be true
      expect(host.send(:time_in_interval?, 110.0, 0)).to be true
    end

    it "is false just outside the window" do
      host = build_normalized_host

      expect(host.send(:time_in_interval?, 89.0, 0)).to be false
      expect(host.send(:time_in_interval?, 111.0, 0)).to be false
    end
  end

  describe "#compute_normalized_time" do
    it "maps the midpoint to zero and the window edges to plus/minus one" do
      host = build_normalized_host

      expect(host.send(:compute_normalized_time, 100.0, 0)).to eq(0.0)
      expect(host.send(:compute_normalized_time, 110.0, 0)).to eq(1.0)
      expect(host.send(:compute_normalized_time, 90.0, 0)).to eq(-1.0)
      expect(host.send(:compute_normalized_time, 105.0, 0)).to eq(0.5)
    end
  end

  describe "#process_coefficient_data" do
    it "splits each record into a midpoint, a radius, and coefficients" do
      host = build_host(component_count: 2)
      raw = [
        100.0, 10.0, 1.0, 2.0, 3.0, 4.0,
        200.0, 20.0, 5.0, 6.0, 7.0, 8.0
      ]
      record_size = 6
      segment_count = 2
      coefficient_count = 2

      host.send(
        :process_coefficient_data,
        [raw, record_size, segment_count, coefficient_count]
      )

      expect(host.midpoints).to eq([100.0, 200.0])
      expect(host.radii).to eq([10.0, 20.0])
      expect(host.coefficients).to eq(
        [
          [[1.0, 3.0], [2.0, 4.0]],
          [[5.0, 7.0], [6.0, 8.0]]
        ]
      )
    end
  end

  describe "#generate_position" do
    it "evaluates the polynomial at the normalized time" do
      host = build_evaluation_host

      result = host.send(:generate_position, 0.5)

      expect(result).to eq([6.0, 12.0, 18.0])
    end
  end

  describe "#generate_single" do
    it "returns a position identical to the standalone evaluation" do
      host = build_evaluation_host

      position, = host.send(:generate_single, 0.5)

      expect(position).to eq(host.send(:generate_position, 0.5))
    end

    it "returns a velocity identical to the standalone derivative" do
      host = build_evaluation_host
      expected_velocity = Ephem::Computation::ChebyshevPolynomial
        .evaluate_derivative(evaluation_coefficients, 0.5, 1.0)

      _position, velocity = host.send(:generate_single, 0.5)

      expect(velocity).to eq(expected_velocity)
    end
  end

  def build_host(component_count: 3)
    ChebyshevType2TestHost.new(component_count: component_count)
  end

  def build_search_host
    ChebyshevType2TestHost.new(
      midpoints: [100.0, 300.0],
      radii: [10.0, 10.0]
    )
  end

  def overwrite_cache_after_check(host, other_interval:)
    allow(host).to receive(:time_in_interval?)
      .and_wrap_original do |original, *arguments|
        covered = original.call(*arguments)
        host.instance_variable_set(:@last_interval, other_interval)
        covered
      end
  end

  def build_normalized_host
    ChebyshevType2TestHost.new(midpoints: [100.0], radii: [10.0])
  end

  def build_evaluation_host
    ChebyshevType2TestHost.new(
      midpoints: [0.0],
      radii: [1.0],
      coefficients: [evaluation_coefficients]
    )
  end

  def evaluation_coefficients
    [[1.0, 2.0, 3.0], [10.0, 20.0, 30.0]]
  end
end
