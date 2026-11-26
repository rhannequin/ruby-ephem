# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "stringio"

RSpec.describe Ephem::CLI do
  include TestSpkHelper

  describe ".gregorian_to_julian" do
    it "converts a date to the Julian Date at midnight" do
      julian_date = Ephem::CLI.gregorian_to_julian("2000-01-01")

      expect(julian_date).to eq(2451544.5)
    end

    it "converts multiple dates" do
      expected_julian_dates = {
        "2000-01-01" => 2451544.5,
        "2020-12-31" => 2459214.5,
        "1900-01-01" => 2415020.5
      }

      expected_julian_dates.each do |date_str, expected_julian_date|
        julian_date = Ephem::CLI.gregorian_to_julian(date_str)

        expect(julian_date).to eq(expected_julian_date)
      end
    end

    it "reads dates before 1582 in the proleptic Gregorian calendar" do
      julian_date = Ephem::CLI.gregorian_to_julian("1000-01-01")

      expect(julian_date).to eq(2086302.5)
    end

    it "raises an error for invalid dates" do
      invalid_dates =
        ["not-a-date", "2000/13/01", "2000-02-30", "10", "jan 5", "2000-01-01x"]

      invalid_dates.each do |date_str|
        expect { Ephem::CLI.gregorian_to_julian(date_str) }
          .to raise_error(Date::Error)
      end
    end
  end

  describe ".parse_target_ids" do
    it "parses a comma-separated list of integers" do
      target_ids = Ephem::CLI.parse_target_ids("3, 10,-399")

      expect(target_ids).to eq([3, 10, -399])
    end

    it "rejects values that are not integers" do
      invalid_values = ["foo", "3,foo", "3,,10", "3.5", "0x10", ",", ""]

      invalid_values.each do |value|
        expect { Ephem::CLI.parse_target_ids(value) }
          .to raise_error(OptionParser::InvalidArgument)
      end
    end
  end

  describe ".show_help" do
    it "displays help information" do
      output = capture_stdout { Ephem::CLI.show_help }

      expect(output).to include("Ruby Ephem")
      expect(output).to include("excerpt")
      expect(output).to include("--targets")
      expect(output).to include("Examples:")
    end
  end

  describe ".start" do
    it "shows usage on stderr and fails when no arguments given" do
      result = run_cli { Ephem::CLI.start([]) }

      expect(result[:status]).to eq(1)
      expect(result[:stdout]).to be_empty
      expect(result[:stderr]).to include("Usage: ruby-ephem excerpt")
    end

    it "shows help and succeeds when help command given" do
      result = run_cli { Ephem::CLI.start(["help"]) }

      expect(result[:status]).to eq(0)
      expect(result[:stdout]).to include("Ruby Ephem")
      expect(result[:stdout]).to include("Commands:")
    end

    it "runs excerpt command and returns its exit status" do
      allow(Ephem::CLI).to receive(:handle_excerpt).and_return(0)

      status = Ephem::CLI.start(%w[excerpt arg1 arg2])

      expect(Ephem::CLI).to have_received(:handle_excerpt)
        .with(%w[arg1 arg2])
      expect(status).to eq(0)
    end

    it "shows an error on stderr and fails for an unknown command" do
      result = run_cli { Ephem::CLI.start(["unknown_command"]) }

      expect(result[:status]).to eq(1)
      expect(result[:stdout]).to be_empty
      expect(result[:stderr]).to include("Unknown command: unknown_command")
      expect(result[:stderr]).to include("Available commands")
    end
  end

  describe ".handle_excerpt" do
    context "with insufficient arguments" do
      it "shows an error on stderr and fails" do
        result = run_cli { Ephem::CLI.handle_excerpt([]) }

        expect_failure(result, "Expected 4 arguments, got 0")
      end
    end

    context "with too many arguments" do
      it "shows an error on stderr and fails" do
        args = %w[2000-01-01 2030-01-01 input.bsp output.bsp extra]

        result = run_cli { Ephem::CLI.handle_excerpt(args) }

        expect_failure(result, "Expected 4 arguments, got 5")
      end
    end

    context "with an unknown option" do
      it "shows an error on stderr and fails" do
        args = %w[--unknown 2000-01-01 2030-01-01 input.bsp output.bsp]

        result = run_cli { Ephem::CLI.handle_excerpt(args) }

        expect_failure(result, "invalid option: --unknown")
      end
    end

    context "with --targets missing its value" do
      it "shows an error on stderr and fails" do
        result = run_cli { Ephem::CLI.handle_excerpt(["--targets"]) }

        expect_failure(result, "missing argument: --targets")
      end
    end

    context "with --targets that are not integers" do
      it "shows an error on stderr and fails without writing a file" do
        within_temp_dir do |temp_dir|
          input_file = copy_fixture(test_spk, temp_dir, "input.bsp")
          output_file = File.join(temp_dir, "output.bsp")
          args = excerpt_args(input_file, output_file, "--targets", "foo")

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect_failure(result, "invalid argument: --targets foo")
          expect(File.exist?(output_file)).to be false
        end
      end
    end

    context "with nonexistent input file" do
      it "shows an error on stderr and fails" do
        args = %w[2000-01-01 2030-01-01 nonexistent.bsp output.bsp]

        result = run_cli { Ephem::CLI.handle_excerpt(args) }

        expect_failure(result, "does not exist")
      end
    end

    context "with invalid date format" do
      it "shows an error on stderr and fails" do
        within_temp_dir do |temp_dir|
          input_file = copy_fixture(test_spk, temp_dir, "input.bsp")
          output_file = File.join(temp_dir, "output.bsp")
          args = ["not-a-date", "2030-01-01", input_file, output_file]

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect_failure(result, "Error parsing dates")
        end
      end
    end

    context "with the same input and output file" do
      it "shows an error on stderr and fails without touching the input" do
        within_temp_dir do |temp_dir|
          input_file = copy_fixture(test_spk, temp_dir, "input.bsp")
          original_size = File.size(input_file)
          args = excerpt_args(input_file, input_file)

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect_failure(result, "must be different from the input file")
          expect(File.size(input_file)).to eq(original_size)
        end
      end
    end

    context "with a start date after the end date" do
      it "shows an error on stderr and fails" do
        within_temp_dir do |temp_dir|
          input_file = copy_fixture(test_spk, temp_dir, "input.bsp")
          output_file = File.join(temp_dir, "output.bsp")
          args = ["2030-01-01", "2000-01-01", input_file, output_file]

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect_failure(result, "START_DATE must not be after END_DATE")
          expect(File.exist?(output_file)).to be false
        end
      end
    end

    context "with a date string too long to parse" do
      it "shows an error on stderr and fails" do
        within_temp_dir do |temp_dir|
          input_file = copy_fixture(test_spk, temp_dir, "input.bsp")
          output_file = File.join(temp_dir, "output.bsp")
          long_date = "2000-01-01" + " " * 200
          args = [long_date, "2030-01-01", input_file, output_file]

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect_failure(result, "Error parsing dates")
        end
      end
    end

    context "with an input file that is not a kernel" do
      it "shows an error on stderr and fails" do
        within_temp_dir do |temp_dir|
          input_file = File.join(temp_dir, "input.bsp")
          File.write(input_file, "not a kernel")
          output_file = File.join(temp_dir, "output.bsp")
          args = excerpt_args(input_file, output_file)

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect(result[:status]).to eq(1)
          expect(result[:stderr]).to include("Error creating excerpt")
        end
      end
    end

    context "with valid arguments" do
      it "creates an excerpt with specified targets" do
        within_temp_dir do |temp_dir|
          input_file = copy_fixture(test_spk, temp_dir, "input.bsp")
          output_file = File.join(temp_dir, "output.bsp")
          args = excerpt_args(input_file, output_file, "--targets", "3,10,399")

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect(result[:status]).to eq(0)
          expect(result[:stderr]).to be_empty
          expect(result[:stdout]).to include("Creating excerpt")
          expect(result[:stdout]).to include("JD 2451544.5 to 2462502.5")
          expect(result[:stdout]).to include("Including targets: 3, 10, 399")
          expect(result[:stdout]).to include("Excerpt created successfully")
          expect(File.exist?(output_file)).to be true
        end
      end

      it "creates an excerpt with all targets when none specified" do
        within_temp_dir do |temp_dir|
          input_file = copy_fixture(test_spk, temp_dir, "input.bsp")
          output_file = File.join(temp_dir, "output.bsp")
          args = excerpt_args(input_file, output_file)

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect(result[:status]).to eq(0)
          expect(result[:stdout]).to include("Creating excerpt")
          expect(result[:stdout]).to include("Including all targets")
          expect(result[:stdout]).to include("Excerpt created successfully")
          expect(File.exist?(output_file)).to be true
        end
      end

      it "shows debug output when requested" do
        within_temp_dir do |temp_dir|
          input_file = copy_fixture(test_spk, temp_dir, "input.bsp")
          output_file = File.join(temp_dir, "output.bsp")
          args = excerpt_args(input_file, output_file, "--debug")

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect(result[:status]).to eq(0)
          expect(result[:stdout]).to include("Creating excerpt")
          expect(File.exist?(output_file)).to be true
        end
      end

      it "excerpts a binary PCK kernel, detecting the format" do
        within_temp_dir do |temp_dir|
          input_file =
            copy_fixture(moon_pa_de440_excerpt, temp_dir, "input.bpc")
          output_file = File.join(temp_dir, "output.bpc")
          args = [
            "--targets",
            "31008",
            "2001-01-01",
            "2002-01-01",
            input_file,
            output_file
          ]

          result = run_cli { Ephem::CLI.handle_excerpt(args) }

          expect(result[:status]).to eq(0)
          expect(result[:stdout]).to include("Excerpt created successfully")
          excerpt = Ephem::PCK.open(output_file)
          expect(excerpt[31008].body).to eq(31008)
          excerpt.close
        end
      end
    end
  end

  describe ".open_kernel" do
    it "opens a binary PCK file as Ephem::PCK" do
      kernel = Ephem::CLI.open_kernel(moon_pa_de440_excerpt)

      expect(kernel).to be_a(Ephem::PCK)

      kernel.close
    end

    it "opens an SPK file as Ephem::SPK" do
      kernel = Ephem::CLI.open_kernel(test_spk)

      expect(kernel).to be_a(Ephem::SPK)

      kernel.close
    end

    it "closes the DAF when the kernel cannot be built" do
      daf = instance_double(Ephem::IO::DAF, file_type: :pck)
      allow(File).to receive(:open).and_return(instance_double(File))
      allow(Ephem::IO::DAF).to receive(:new).and_return(daf)
      allow(Ephem::PCK).to receive(:new).and_raise(Ephem::UnsupportedError)

      expect(daf).to receive(:close)
      expect { Ephem::CLI.open_kernel("kernel.bpc") }
        .to raise_error(Ephem::UnsupportedError)
    end
  end

  def excerpt_args(input_file, output_file, *options)
    [*options, "2000-01-01", "2030-01-01", input_file, output_file]
  end

  def expect_failure(result, message)
    expect(result[:status]).to eq(1)
    expect(result[:stdout]).to be_empty
    expect(result[:stderr]).to include(message)
  end

  def within_temp_dir
    temp_dir = Dir.mktmpdir("ephem_test_")
    yield temp_dir
  ensure
    FileUtils.remove_entry(temp_dir)
  end

  def copy_fixture(fixture_path, temp_dir, file_name)
    destination = File.join(temp_dir, file_name)
    FileUtils.cp(fixture_path, destination)
    destination
  end

  def run_cli
    original_stdout = $stdout
    original_stderr = $stderr
    $stdout = StringIO.new
    $stderr = StringIO.new
    status = yield
    {status: status, stdout: $stdout.string, stderr: $stderr.string}
  ensure
    $stdout = original_stdout
    $stderr = original_stderr
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
