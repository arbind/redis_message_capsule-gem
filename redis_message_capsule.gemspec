# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'redis_message_capsule/version'

Gem::Specification.new do |gem|
  gem.name          = "redis_message_capsule"
  gem.version       = RedisMessageCapsule::VERSION
  gem.authors       = ["Arbind"]
  gem.email         = ["arbind@carbonfive.com"]
  gem.description   = "Send and receive real-time messages between applications (via redis)."
  gem.summary       = ""
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]


  gem.add_runtime_dependency 'redis'
  gem.add_runtime_dependency 'json'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'simplecov'

end
