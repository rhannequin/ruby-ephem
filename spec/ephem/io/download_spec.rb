# frozen_string_literal: true

RSpec.describe Ephem::IO::Download do
  describe ".call" do
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
