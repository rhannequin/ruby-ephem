# frozen_string_literal: true

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
    puts "Usage: rake validate_accuracy date=1900 kernel=de440 target=1"
    exit 1
  end

  unless Ephem::Tasks::ValidateAccuracy
      .run(date: date, kernel: kernel, target: target)
    exit 1
  end
end

desc "Run validation accuracy checks. "
