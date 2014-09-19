# encoding: utf-8
Gem::Specification.new do |s|
  s.name = "bolt"
  s.version = "0.1.0" #  http://semver.org/  +  http://guides.rubygems.org/specification-reference
  s.author = "elpulgardelpanda"
  s.email = "tech@elpulgardelpanda.com"
  s.platform = Gem::Platform::RUBY
  s.summary = "A world-record-fast task runner based on Ruby processes"
  s.files = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- test/*`.split("\n")
  s.require_path = "lib"
  s.required_ruby_version = '>= 2.1.0'
  s.has_rdoc = false
end
