# frozen_string_literal: true

require "open3"
require "rbconfig"

RSpec.describe Ephem do
  it "has a version number" do
    expect(Ephem::VERSION).not_to be nil
  end

  it "does not load optional standard libraries on require" do
    script = <<~RUBY
      require "ephem"
      print %w[Net OptionParser Date Tempfile Zlib]
        .select { |name| Object.const_defined?(name, false) }
        .join(",")
    RUBY

    expect(run_isolated_ruby(script)).to eq("")
  end

  it "loads CLI, Download and Excerpt on first use" do
    script = <<~RUBY
      require "ephem"
      print [Ephem::CLI, Ephem::Download, Ephem::Excerpt::DAFWriter]
        .map(&:name)
        .join(",")
      print ",", Object.const_defined?("Net::HTTP")
    RUBY

    expect(run_isolated_ruby(script))
      .to eq("Ephem::CLI,Ephem::Download,Ephem::Excerpt::DAFWriter,true")
  end

  def run_isolated_ruby(script)
    lib_path = File.expand_path("../lib", __dir__)
    output, errors, status = Open3.capture3(
      RbConfig.ruby, "--disable-gems", "-I", lib_path, "-e", script
    )
    raise "Ruby subprocess failed: #{errors}" unless status.success?

    output
  end
end
