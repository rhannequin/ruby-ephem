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
          "ephemeris" => "de405",
          "julian_date" => "2415021.0000000000000000",
          "target" => "1",
          "center" => "0",
          "x" => "-5.7066714820133306e+07",
          "y" => "-2.4386501773079373e+07",
          "z" => "-7.1431067080760906e+06",
          "vx" => "8.7264193806159205e+05",
          "vy" => "-3.1941322440840057e+06",
          "vz" => "-1.7965355115999668e+06"
        ]
        allow(CSV).to receive(:foreach).and_return(csv_content.each)

        expect(described_class.run).to be true
      end
    end

    context "when a validation doesn't pass" do
      it "returns false" do
        csv_content = [
          "ephemeris" => "de405",
          "julian_date" => "2415021.0000000000000000",
          "target" => "1",
          "center" => "0",
          "x" => "0",
          "y" => "0",
          "z" => "0",
          "vx" => "0",
          "vy" => "0",
          "vz" => "0"
        ]
        allow(CSV).to receive(:foreach).and_return(csv_content.each)

        expect(described_class.run).to be false
      end
    end
  end
end
