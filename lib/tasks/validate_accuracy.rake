# frozen_string_literal: true

require_relative "../ephem/tasks/validate_accuracy"

desc "Validate accuracy of library by comparing with python-jplephem"
task :validate_accuracy do
  exit 1 unless Ephem::Tasks::ValidateAccuracy.run
end
