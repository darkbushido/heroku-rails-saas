Gem::Specification.new do |s|
  s.name = "heroku-rails-saas"
  s.version = "0.1.3"

  s.authors = [ "Elijah Miller", "Glenn Roberts", "Jacques Crocker", "Lance Sanchez"]

  s.summary = "Deployment and configuration tools for Heroku/Rails"
  s.description = "Manage multiple Heroku instances/apps for a single Rails app using Rake."

  s.email = "railsjedi@gmail.com"
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

  s.add_runtime_dependency "heroku", ">= 2.24.1"
  s.add_development_dependency "rspec", "~> 2.0"
end

