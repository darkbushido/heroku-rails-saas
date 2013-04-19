Gem::Specification.new do |s|
  s.name = "heroku-rails-saas"
  s.version = "0.1.7"

  s.authors = [ "Elijah Miller", "Glenn Roberts", "Jacques Crocker", "Lance Sanchez", "Chris Trinh"]

  s.summary = "Deployment and configuration tools for Heroku/Rails"
  s.description = "Manage multiple Heroku instances/apps for a single Rails app using Rake."

  s.email = "lance.sanchez@gmail.com"
  s.homepage = "http://github.com/darkbushido/heroku-rails-saas"
  s.rubyforge_project = "none"

  s.require_paths = ["lib"]
  s.files = Dir['lib/**/*',
                'spec/**/*',
                'heroku-rails.gemspec',
                'Gemfile',
                'Gemfile.lock',
                'CHANGELOG',
                'LICENSE',
                'Rakefile',
                'README.md',
                'TODO']

  s.test_files = Dir['spec/**/*']
  s.rdoc_options = ["--charset=UTF-8"]
  s.extra_rdoc_files = [
    "LICENSE",
    "README.md",
    "TODO",
    "CHANGELOG"
  ]

  s.add_runtime_dependency "rails"
  s.add_runtime_dependency "heroku-api", "~> 0.3.8"
  s.add_runtime_dependency "netrc", "~> 0.7.7"
  s.add_runtime_dependency "parallel", "~> 0.6.2"
  s.add_runtime_dependency "rendezvous", "~> 0.0.2"
  s.add_development_dependency "rspec", "~> 2.0"
end