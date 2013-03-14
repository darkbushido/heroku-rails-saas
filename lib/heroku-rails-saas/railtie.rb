require_relative 'config'
require_relative 'runner'

module HerokuRailsSaas
  class Railtie < ::Rails::Railtie
    rake_tasks do
      HerokuRailsSaas::Config.root = ::Rails.root
      load 'heroku/rails/tasks.rb'
    end
  end
end
