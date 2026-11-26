# frozen_string_literal: true

require "tempfile"
require "ephem/tasks/validate_testpo"

RSpec.describe Ephem::Tasks::ValidateTestpo do
  include TestSpkHelper

  describe ".run" do
    it "matches every row of the IMCCE testpo file for INPOP21a" do
      result = nil

      expect { result = described_class.run(kernel: "inpop21a") }
        .to output(/testpo validations passed/).to_stdout
      expect(result).to be true
    end
  end

  describe "#run" do
    it "returns true when the computed values match the testpo rows" do
      testpo_rows = [
        "100  2000.01.02 2451545.5  7  4  2      -12.51334491525322611949"
      ]

      with_testpo_file(testpo_rows) do |testpo_path|
        validation = build_validation(testpo_path)

        expect { expect(validation.run).to be true }
          .to output(/1 testpo validations passed/).to_stdout
      end
    end

    it "returns false and reports the rows beyond the tolerance" do
      wrong_row =
        "100  2000.01.02 2451545.5  7  4  2      -12.51334491525300000000"

      with_testpo_file([wrong_row]) do |testpo_path|
        validation = build_validation(testpo_path)

        expect { expect(validation.run).to be false }
          .to output(/1 of 1 testpo validations failed.*\n  #{wrong_row}/)
          .to_stdout
      end
    end
  end

  def build_validation(testpo_path)
    described_class.new(
      kernel_path: inpop21a_2000_excerpt,
      testpo_path: testpo_path
    )
  end

  def with_testpo_file(rows)
    header = [
      "INPOP21A_TDB",
      "KSIZE= 1876",
      "",
      "INPOP#\t -- date -- -- jed -- t# c# x# -- coordinate ---",
      "EOT"
    ]
    Tempfile.create("testpo") do |file|
      file.write((header + rows).join("\n"))
      file.flush
      yield file.path
    end
  end
end
