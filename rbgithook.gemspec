# frozen_string_literal: true

require_relative "lib/rbgithook/version"

Gem::Specification.new do |spec|
  spec.name = "rbgithook"
  spec.version = Rbgithook::VERSION
  spec.authors = ["hyuraku"]
  spec.email = ["32809703+hyuraku@users.noreply.github.com"]

  spec.summary = "Git hook by Ruby"
  spec.description = "Simple Git hook made by Ruby"
  spec.homepage = "https://github.com/hyuraku/rbgithook"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/hyuraku/rbgithook"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
