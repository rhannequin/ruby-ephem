# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

Dir.glob("lib/tasks/**/*.rake").each { |r| load r }

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec standard]
