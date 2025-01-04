# frozen_string_literal: true

require "ephem/tasks/validate_accuracy"

RSpec.describe Ephem::Tasks::ValidateAccuracy do
  before do
    @original_stdout = $stdout
    $stdout = StringIO.new
  end

  after do
    $stdout = @original_stdout
  end

  describe ".run" do
    context "when the task succeeds" do
      it "returns true" do
        csv_content = [
          "julian_date" => "2451546",
          "center" => "0",
          "x" => "-1.7305359679278996e+07",
          "y" => "-6.0974293023407288e+07",
          "z" => "-3.0812429629787814e+07",
          "vx" => "3.2491819082937399e+06",
          "vy" => "-5.6242306220424012e+05",
          "vz" => "-6.3724054778491484e+05"
        ]
        date = "2000"
        kernel = "de405"
        target = "1"
        allow(CSV).to receive(:foreach).and_return(csv_content.each)

        run = described_class.run(date: date, kernel: kernel, target: target)

        expect(run).to be true
      end
    end

    context "when a validation doesn't pass" do
      it "returns false" do
        csv_content = [
          "julian_date" => "2451546",
          "center" => "0",
          "x" => "0",
          "y" => "0",
          "z" => "0",
          "vx" => "0",
          "vy" => "0",
          "vz" => "0"
        ]
        date = "2000"
        kernel = "de405"
        target = "1"
        allow(CSV).to receive(:foreach).and_return(csv_content.each)

        run = described_class.run(date: date, kernel: kernel, target: target)

        expect(run).to be false
      end
    end
  end
end
