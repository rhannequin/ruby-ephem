# frozen_string_literal: true

RSpec.describe Ephem::PCK do
  include TestSpkHelper

  describe ".open" do
    it "opens a binary PCK file" do
      pck = described_class.open(moon_pa_de440_excerpt)

      expect(pck).to be_a(described_class)
      expect(pck.daf.file_type).to eq(:pck)

      pck.close
    end

    it "rejects an SPK file" do
      expect { described_class.open(test_spk) }.to raise_error(
        ArgumentError, /not a binary PCK/
      )
    end
  end

  describe "#[]" do
    it "returns the orientation source for a body frame" do
      pck = described_class.open(moon_pa_de440_excerpt)

      source = pck[31008]
      expect(source.body).to eq(31008)
      expect(source.reference_frame).to eq(1)

      pck.close
    end

    it "raises KeyError for an unknown body" do
      pck = described_class.open(moon_pa_de440_excerpt)

      expect { pck[42] }.to raise_error(
        KeyError, /No orientation segment found for body: 42/
      )

      pck.close
    end
  end

  describe "#to_s" do
    it "describes the file and its segments" do
      pck = described_class.open(moon_pa_de440_excerpt)

      expect(pck.to_s).to include("PCK file with 1 segments")
      expect(pck.to_s).to include("orientation of frame 31008")

      pck.close
    end
  end

  describe "data type support" do
    it "raises UnsupportedError for a non type-2 segment" do
      descriptor = [0.0, 1.0, 31008, 1, 3, 1, 100]
      daf = instance_double(Ephem::IO::DAF)
      allow(daf).to receive(:summaries).and_return([["src", descriptor]])

      expect { described_class.new(daf: daf) }.to raise_error(
        Ephem::UnsupportedError, /Unsupported PCK data type: 3/
      )
    end
  end

  describe "a body split across multiple segments" do
    it "is served by an OrientationGroup" do
      pck = described_class.open(moon_pa_de440_boundary_excerpt)

      group = pck[31008]
      expect(group).to be_a(Ephem::Segments::OrientationGroup)
      expect(group.segments.size).to eq(2)

      pck.close
    end

    it "routes each time to the segment that covers it" do
      pck = described_class.open(moon_pa_de440_boundary_excerpt)
      group = pck[31008]
      early_segment, late_segment = group.segments
      early_time = early_segment.start_jd + 10
      late_time = late_segment.start_jd + 10

      expect(group.angles_at(early_time).to_a)
        .to eq(early_segment.angles_at(early_time).to_a)
      expect(group.angles_at(late_time).to_a)
        .to eq(late_segment.angles_at(late_time).to_a)

      pck.close
    end

    it "preserves input order for an array spanning both segments" do
      pck = described_class.open(moon_pa_de440_boundary_excerpt)
      group = pck[31008]
      early_segment, late_segment = group.segments
      early_time = early_segment.start_jd + 10
      late_time = late_segment.start_jd + 10

      results = group.angles_at([late_time, early_time])

      expect(results[0].to_a).to eq(late_segment.angles_at(late_time).to_a)
      expect(results[1].to_a).to eq(early_segment.angles_at(early_time).to_a)

      pck.close
    end

    it "rejects position queries with a helpful error" do
      pck = described_class.open(moon_pa_de440_boundary_excerpt)
      group = pck[31008]

      expect { group.compute(2452000.0) }.to raise_error(
        NotImplementedError, /angles_at or #orientation_at/
      )
      expect { group.compute_and_differentiate(2452000.0) }.to raise_error(
        NotImplementedError, /orientation_at/
      )

      pck.close
    end
  end

  describe "accuracy against jplephem (MOON_PA_DE440)" do
    it "matches reference Euler angles and rates" do
      pck = described_class.open(moon_pa_de440_excerpt)
      source = pck[31008]

      reference_orientations.each do |reference|
        orientation = source.orientation_at(reference[:jd])

        orientation.to_a.zip(reference[:angles]).each do |actual, expected|
          expect(actual).to be_within(1e-9).of(expected)
        end
        orientation.rates.zip(reference[:rates]).each do |actual, expected|
          expect(actual).to be_within(1e-9).of(expected)
        end
      end

      pck.close
    end
  end

  # Ground truth from jplephem 2.24 reading moon_pa_de440_200625.bpc.
  # Rates converted to ephem's per-day convention (jplephem returns per second).
  def reference_orientations
    [
      {
        jd: 2452000.0,
        angles: [-0.0645389064927909, 0.415637068726414, 2668.90512416828],
        rates: [0.000371042029495874, -0.00014568869379002, 0.229623457019946]
      },
      {
        jd: 2456000.0,
        angles: [0.0609875385648408, 0.419110500824661, 3588.67325163054],
        rates: [-0.000208821705039922, 9.83855110550238e-05, 0.230149931169316]
      },
      {
        jd: 2460000.0,
        angles: [-0.0423518935446004, 0.387741447813132, 4508.65143781339],
        rates: [4.41729372107692e-05, -7.15944475461727e-05, 0.229930175592345]
      }
    ]
  end
end
