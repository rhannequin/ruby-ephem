# frozen_string_literal: true

RSpec.describe Ephem::IO::Download do
  describe ".call" do
    it "returns true" do
      allow(URI).to receive(described_class::BASE_URL + "de434.bsp")
      allow(Net::HTTP).to receive(:get).and_return("content")

      download = described_class.call(
        name: "de431.bsp",
        target: "tmp/de431.bsp"
      )

      expect(download).to be true
    end

    context "when the kernel is not supported" do
      it "raises an UnsupportedError" do
        expect { described_class.call(name: "unsupported", target: "path") }.to(
          raise_error(
            Ephem::UnsupportedError,
            "Kernel unsupported is not supported by the library at the moment."
          )
        )
      end
    end
  end
end
