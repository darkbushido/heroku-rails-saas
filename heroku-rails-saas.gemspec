require File.expand_path('../lib/heroku-rails-saas/version', __FILE__)

Gem::Specification.new do |gem|
  gem.name              = "heroku-rails-saas"
  gem.version           = HerokuRailsSaas::VERSION
  gem.authors           = ["Elijah Miller", "Glenn Roberts", "Jacques Crocker", "Lance Sanchez", "Chris Trinh"]
  gem.summary           = "Deployment and configuration tools for Heroku/Rails"
  gem.description       = "Manage multiple Heroku instances/apps for a single Rails app using Rake."
  gem.email             = "lance.sanchez@gmail.com"
  gem.homepage          = "http://github.com/darkbushido/heroku-rails-saas"
  gem.rubyforge_project = "none"
  gem.require_paths     = ["lib"]
  gem.files             = `git ls-files | grep -Ev '^(myapp|examples)'`.split("\n")
  gem.test_files        = `git ls-files -- spec/*`.split("\n")
  gem.rdoc_options      = ["--charset=UTF-8"]
  gem.extra_rdoc_files  = ["LICENSE", "README.md", "TODO", "CHANGELOG"]

  gem.add_runtime_dependency "rails"
  gem.add_runtime_dependency "heroku-api", "~> 0.3.13"
  gem.add_runtime_dependency "netrc", "~> 0.7.7"
  gem.add_runtime_dependency "parallel", "~> 0.6.2"
  gem.add_runtime_dependency "rendezvous", "~> 0.0.2"
  gem.add_development_dependency "rspec", "~> 2.0"
  gem.add_development_dependency "webmock", "~> 1.11.0"
end