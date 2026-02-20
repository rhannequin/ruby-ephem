# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

Dir.glob("lib/tasks/**/*.rake").each { |r| load r }

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

begin
  require "rake/extensiontask"

  Rake::ExtensionTask.new("chebyshev") do |ext|
    ext.lib_dir = "lib/ephem"
    ext.ext_dir = "ext/ephem/chebyshev"
  end

  task spec: :compile
rescue LoadError
  # rake-compiler not available; skip extension compilation tasks.
end

task default: %i[spec standard]
