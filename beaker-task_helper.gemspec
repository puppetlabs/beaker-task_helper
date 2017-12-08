# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "beaker/task_helper/version"

Gem::Specification.new do |spec|
  spec.name          = "beaker-task_helper"
  spec.version       = Beaker::TaskHelper::VERSION
  spec.authors       = ["puppet"]
  spec.email         = ["info@puppet.com"]

  spec.summary       = %q{Ruby gem to help testing tasks with Beaker}
  spec.homepage      = "https://github.com/puppetlabs/beaker-task_helper"
  spec.license       = "Apache-2"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'beaker', '>= 3.0.0'
  spec.add_development_dependency 'beaker-rspec'
  spec.add_development_dependency 'pry'

  spec.add_runtime_dependency 'open3'
end
