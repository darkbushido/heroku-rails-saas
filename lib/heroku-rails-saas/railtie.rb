require_relative 'config'
require_relative 'runner'

module HerokuRailsSaas
  class Railtie < ::Rails::Railtie
    rake_tasks do
      HerokuRailsSaas::Config.root = ::Rails.root
      if ::Rails.env.development?
        puts "Load heroku-rails-saas rake task"
        load 'heroku/rails/tasks.rb'
      end
    end
  end
end