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
        jd: 2451045.0,
        angles: [-0.0310089214024731, 0.432874655509576, 2449.25118158446],
        rates: [-5.27075482126779e-05, 7.60544162825503e-06, 0.230015478199546]
      },
      {
        jd: 2451545.0,
        angles: [-0.0541470580870196, 0.424855460999069, 2564.25827272151],
        rates: [-0.000117018175276388, 4.51324219231248e-05, 0.230100034112187]
      },
      {
        jd: 2452045.0,
        angles: [-0.0683791305700164, 0.413710101076473, 2679.25713036353],
        rates: [-0.000132116376724321, 0.000171517329456927, 0.230098834913826]
      }
    ]
  end
end
