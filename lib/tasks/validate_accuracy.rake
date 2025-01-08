# frozen_string_literal: true

require "parallel"

require_relative "../ephem/tasks/validate_accuracy"

desc "
Validate accuracy of library by comparing with python-jplephem.
Usage: rake validate_accuracy date=1900 kernel=de440 target=1
"
task :validate_accuracy do
  date = ENV["date"]
  kernel = ENV["kernel"]
  target = ENV["target"]

  unless date && kernel && target
    puts "Error: All parameters are required"
    puts "Usage: rake validate_accuracy date=2000 kernel=de440s target=1"
    exit 1
  end

  unless Ephem::Tasks::ValidateAccuracy
      .run(date: date, kernel: kernel, target: target)
    exit 1
  end
end

namespace :validate_accuracy do
  task :all do
    kernels = Ephem::Tasks::ValidateAccuracy::KERNELS.keys
    targets = (1..10).to_a.map(&:to_s)

    parameter_sets = kernels.product(targets).map do |kernel, target|
      {date: "2000", kernel: kernel, target: target}
    end

    results = Parallel.map(parameter_sets, in_processes: 10) do |params|
      Ephem::Tasks::ValidateAccuracy.run(
        date: params[:date],
        kernel: params[:kernel],
        target: params[:target]
      )
    end

    exit 1 if results.any?(FalseClass)
  end
end
