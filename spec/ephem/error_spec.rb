# frozen_string_literal: true

RSpec.describe "Ephem errors" do
  it "makes OutOfRangeError rescuable as Ephem::Error" do
    error = Ephem::OutOfRangeError.new("out of range", [2451545.0])

    expect(error).to be_a(Ephem::Error)
    expect(error.out_of_range_times).to eq([2451545.0])
  end

  it "makes ClosedKernelError and DownloadError rescuable as Ephem::Error" do
    expect(Ephem::ClosedKernelError.new).to be_a(Ephem::Error)
    expect(Ephem::DownloadError.new).to be_a(Ephem::Error)
  end

  it "does not shadow the core IndexError" do
    expect(Ephem.const_defined?(:IndexError, false)).to be(false)
  end
end
