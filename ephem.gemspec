# frozen_string_literal: true

require_relative "lib/ephem/version"

Gem::Specification.new do |spec|
  spec.name = "ephem"
  spec.version = Ephem::VERSION
  spec.authors = ["Rémy Hannequin"]
  spec.email = ["remy.hannequin@gmail.com"]

  spec.summary = "Compute astronomical ephemerides from NASA/JPL DE and IMCCE INPOP"
  spec.description = "Ruby implementation of the parsing and computation of ephemerides from NASA/JPL Development Ephemerides DE4xx and IMCCE INPOP"
  spec.homepage = "https://github.com/rhannequin/ruby-ephem"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added
  # into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(
        *%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]
      )
    end
  end
  spec.files += Dir["bin/*"]
  spec.bindir = "bin"
  spec.executables = ["ruby-ephem"]
  spec.require_paths = ["lib"]

  spec.add_dependency "minitar", "~> 0.12"
  spec.add_dependency "numo-narray", "~> 0.9.2.1"
  spec.add_dependency "zlib", "~> 3.2"

  spec.add_development_dependency "csv", "~> 3.3"
  spec.add_development_dependency "irb", "~> 1.15"
  spec.add_development_dependency "parallel", "~> 1.26"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "standard", "~> 1.43"
end
