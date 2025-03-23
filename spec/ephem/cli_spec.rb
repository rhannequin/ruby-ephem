# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "stringio"

RSpec.describe Ephem::CLI do
  include TestSpkHelper

  describe ".gregorian_to_julian" do
    it "converts a simple date correctly" do
      julian_date = Ephem::CLI.gregorian_to_julian("2000-01-01")
      expect(julian_date).to be_within(0.1).of(2451545.0)
    end

    it "converts multiple date formats" do
      formats = {
        "2000-01-01" => 2451545.0,
        "2020-12-31" => 2459215.0,
        "1900-01-01" => 2415021.0
      }

      formats.each do |date_str, expected_jd|
        julian_date = Ephem::CLI.gregorian_to_julian(date_str)
        expect(julian_date).to be_within(0.1).of(expected_jd)
      end
    end

    it "raises an error for invalid dates" do
      invalid_dates = %w[not-a-date 2000/13/01 2000-02-30]

      invalid_dates.each do |date_str|
        expect { Ephem::CLI.gregorian_to_julian(date_str) }
          .to raise_error(Date::Error)
      end
    end
  end

  describe ".show_help" do
    it "displays help information" do
      output = capture_stdout { Ephem::CLI.show_help }

      expect(output).to include("Ruby Ephem")
      expect(output).to include("excerpt")
      expect(output).to include("--targets")
      expect(output).to include("Example:")
    end
  end

  describe ".start" do
    it "shows usage when no arguments given" do
      output = capture_stdout { Ephem::CLI.start([]) }

      expect(output).to include("Usage: ruby-ephem excerpt")
    end

    it "shows help when help command given" do
      output = capture_stdout { Ephem::CLI.start(["help"]) }

      expect(output).to include("Ruby Ephem")
      expect(output).to include("Commands:")
    end

    it "runs excerpt command when given" do
      expect(Ephem::CLI).to receive(:handle_excerpt).with(%w[arg1 arg2])
      Ephem::CLI.start(%w[excerpt arg1 arg2])
    end

    it "shows error for unknown command" do
      output = capture_stdout { Ephem::CLI.start(["unknown_command"]) }

      expect(output).to include("Unknown command")
      expect(output).to include("Available commands")
    end
  end

  describe ".handle_excerpt" do
    context "with insufficient arguments" do
      it "shows an error message" do
        output = capture_stdout { Ephem::CLI.handle_excerpt([]) }

        expect(output).to include("Not enough arguments")
      end
    end

    context "with nonexistent input file" do
      it "shows an error message" do
        args = %w[2000-01-01 2030-01-01 nonexistent.bsp output.bsp]

        output = capture_stdout { Ephem::CLI.handle_excerpt(args) }

        expect(output).to include("does not exist")
      end
    end

    context "with invalid date format" do
      it "shows an error message" do
        args = %w[not-a-date 2030-01-01 input.bsp output.bsp]
        FileUtils.touch("input.bsp")

        begin
          output = capture_stdout { Ephem::CLI.handle_excerpt(args) }
          expect(output).to include("Error parsing dates")
        ensure
          FileUtils.rm("input.bsp") if File.exist?("input.bsp")
        end
      end
    end

    context "with valid arguments" do
      it "creates an excerpt with specified targets" do
        temp_dir = Dir.mktmpdir("ephem_test_")
        input_file = File.join(temp_dir, "input.bsp")
        output_file = File.join(temp_dir, "output.bsp")

        spk_path = test_spk

        begin
          FileUtils.cp(spk_path, input_file)

          args = [
            "--targets",
            "3,10,399",
            "2000-01-01",
            "2030-01-01",
            input_file,
            output_file
          ]
          output = capture_stdout { Ephem::CLI.handle_excerpt(args) }

          expect(output).to include("Creating excerpt")
          expect(output).to include("Including targets: 3, 10, 399")
          expect(output).to include("Excerpt created successfully")
          expect(File.exist?(output_file)).to be true
        ensure
          FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
        end
      end

      it "creates an excerpt with all targets when none specified" do
        temp_dir = Dir.mktmpdir("ephem_test_")
        input_file = File.join(temp_dir, "input.bsp")
        output_file = File.join(temp_dir, "output.bsp")

        spk_path = test_spk

        begin
          FileUtils.cp(spk_path, input_file)

          args = ["2000-01-01", "2030-01-01", input_file, output_file]
          output = capture_stdout { Ephem::CLI.handle_excerpt(args) }

          expect(output).to include("Creating excerpt")
          expect(output).to include("Including all targets")
          expect(output).to include("Excerpt created successfully")
          expect(File.exist?(output_file)).to be true
        ensure
          # Always clean up
          FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
        end
      end

      it "shows debug output when requested" do
        temp_dir = Dir.mktmpdir("ephem_test_")
        input_file = File.join(temp_dir, "input.bsp")
        output_file = File.join(temp_dir, "output.bsp")

        spk_path = test_spk

        begin
          FileUtils.cp(spk_path, input_file)

          args = [
            "--debug",
            "2000-01-01",
            "2030-01-01",
            input_file,
            output_file
          ]
          output = capture_stdout { Ephem::CLI.handle_excerpt(args) }

          expect(output).to include("Creating excerpt")
          expect(File.exist?(output_file)).to be true
        ensure
          FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
        end
      end
    end
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
