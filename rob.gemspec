# -*- encoding: utf-8 -*-

ROB_VERSION ||= "0.1.0"

Gem::Specification.new do |gem|
  gem.authors       = ["Dudley Flanders"]
  gem.email         = ["dudley@zeromtn.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "rob"
  gem.require_paths = ["lib"]
  gem.version       = ROB_VERSION

  gem.add_development_dependency "pry-debugger"
  gem.add_development_dependency "rspec"
end
