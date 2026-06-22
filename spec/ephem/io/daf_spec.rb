# frozen_string_literal: true

RSpec.describe Ephem::IO::DAF do
  include TestSpkHelper

  describe "#file_type" do
    it "identifies a DAF/SPK kernel" do
      daf = described_class.new(File.open(test_spk, "rb"))

      expect(daf.file_type).to eq(:spk)

      daf.close
    end

    it "identifies a binary DAF/PCK kernel" do
      daf = described_class.new(File.open(moon_pa_de440_excerpt, "rb"))

      expect(daf.file_type).to eq(:pck)

      daf.close
    end

    it "falls back to the integer count for a legacy NAIF/DAF SPK" do
      daf = described_class.new(File.open(de405_2000_excerpt, "rb"))

      expect(daf.record_data.locator_identifier).to eq("NAIF/DAF")
      expect(daf.file_type).to eq(:spk)

      daf.close
    end
  end
end
