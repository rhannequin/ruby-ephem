# frozen_string_literal: true

require "ephem/tasks/validate_accuracy"

RSpec.describe Ephem::Tasks::ValidateAccuracy do
  describe ".run" do
    it "returns true when every row matches" do
      stub_rows(mercury_row, mercury_row)

      result = nil
      expect { result = run_task }
        .to output(/\A2 validations passed \(de405\/2000-2050\/1\)/)
        .to_stdout

      expect(result).to be true
    end

    it "returns false when a position does not match" do
      stub_rows(mercury_row.merge("x" => "0"))

      result = nil
      expect { result = run_task }
        .to output(/Position error for de405 at 2451546.0/).to_stdout

      expect(result).to be false
    end

    it "returns false when a velocity does not match" do
      stub_rows(mercury_row.merge("vx" => "0"))

      result = nil
      expect { result = run_task }
        .to output(/Velocity error for de405 at 2451546.0/).to_stdout

      expect(result).to be false
    end
  end

  def run_task
    described_class.run(date: "2000", kernel: "de405", target: "1")
  end

  def stub_rows(*rows)
    allow(CSV).to receive(:foreach).and_return(rows.each)
  end

  def mercury_row
    {
      "julian_date" => "2451546",
      "x" => "-1.7305359679278996e+07",
      "y" => "-6.0974293023407288e+07",
      "z" => "-3.0812429629787814e+07",
      "vx" => "3.2491819082937399e+06",
      "vy" => "-5.6242306220424012e+05",
      "vz" => "-6.3724054778491484e+05"
    }
  end
end
