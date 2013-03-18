require 'heroku-rails-saas'

# Get callback-like rake task to step into the deploy process.
import File.join(File.dirname(__FILE__), '../../generators/templates/heroku.rake')

# Suppress warnings from ruby when trying to redefine a constant, typically due to reloding of Rails.
silence_warnings do
  HEROKU_CONFIG_FILE = File.join(HerokuRailsSaas::Config.root, 'config', 'heroku.yml')
  HEROKU_APP_SPECIFIC_CONFIG_FILES = Dir.glob("#{File.join(HerokuRailsSaas::Config.root, 'config', 'heroku')}/*.yml")
  HEROKU_CONFIG = HerokuRailsSaas::Config.new({:default => HEROKU_CONFIG_FILE, :apps => HEROKU_APP_SPECIFIC_CONFIG_FILES})
  HEROKU_RUNNER = HerokuRailsSaas::Runner.new(HEROKU_CONFIG)
  DISPLAYER = HerokuRailsSaas::Displayer
end

# create all the environment specific tasks
(HEROKU_CONFIG.apps).each do |app, hsh|
  hsh.each do |env, heroku_env|
    local_name = HerokuRailsSaas::Config.local_name(app, env)
    desc "Select #{local_name} Heroku app for later commands"
    task local_name do
      Rake::Task["heroku:switch_environment"].reenable
      Rake::Task["heroku:switch_environment"].invoke

      HEROKU_RUNNER.add_app(local_name)
    end
  end
end

desc 'Select all Heroku apps for later command (production must be explicitly declared)'
task :all do
  HEROKU_RUNNER.all_environments(true)
end

(HEROKU_CONFIG.all_environments).each do |environment|
  desc "Select all Heroku apps in #{environment} environment"
  task "all:#{environment}" do
    HEROKU_RUNNER.add_environment(environment)
  end
end

namespace :heroku do
  desc 'Add git remotes for all apps in this project'
  task :remotes do
    HEROKU_RUNNER.all_environments
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      system("git remote add #{app_name} #{repo}")
    end
  end

  desc 'Lists configured apps'
  task :apps do
    HEROKU_RUNNER.all_environments
    HEROKU_RUNNER.apps
  end

  desc "Run command on the heroku app (e.g. rake task)"
  task :exec, :command do |t, args|
    HEROKU_RUNNER.run(args[:command])
  end

  desc "Get remote server information on the heroku app"
  task :info do
    HEROKU_RUNNER.info
  end

  desc "Deploys, migrates and restarts latest git tag"
  task :deploy => "heroku:before_deploy" do |t, args|
    HEROKU_RUNNER.deploy
  end

  desc "Restarts remote servers"
  task :restart do
    HEROKU_RUNNER.restart
  end

  desc "Scales heroku processes"
  task :scale do
    HEROKU_RUNNER.scale
  end

  desc "Opens a remote console"
  task :console do
    HEROKU_RUNNER.console
  end

  desc "Shows the Heroku logs"
  task :logs do
    HEROKU_RUNNER.logs
  end

  namespace :maintenance do
    desc "Turn maintenance mode on"
    task :on do 
      HEROKU_RUNNER.maintenance(true)
    end

    desc "Tuff maintenance mode off"
    task :off do
      HEROKU_RUNNER.maintenance(false)
    end
  end

  desc "Setup Heroku deploy environment from heroku.yml config"
  task :setup => [
    "heroku:setup:app",
    "heroku:setup:stack",
    "heroku:setup:collaborators",
    "heroku:setup:config",
    "heroku:setup:addons",
    "heroku:setup:domains",
  ]

  namespace :setup do
    desc "Creates the app on Heroku with the default stack"
    task :app do
      HEROKU_RUNNER.setup_app
    end

    desc "Setup the Heroku stacks from heroku.yml config"
    task :stack do
      HEROKU_RUNNER.setup_stack
    end

    desc "Setup the Heroku collaborators from heroku.yml config"
    task :collaborators do
      HEROKU_RUNNER.setup_collaborators
    end

    desc "Setup the Heroku environment config variables from heroku.yml config"
    task :config do
      HEROKU_RUNNER.setup_config
    end

    desc "Setup the Heroku addons from heroku.yml config"
    task :addons do
      HEROKU_RUNNER.setup_addons
    end

    desc "Setup the Heroku domains from heroku.yml config"
    task :domains do
      HEROKU_RUNNER.setup_domains
    end
  end

  namespace :db do
    desc "Migrates and restarts remote servers"
    task :migrate do
      HEROKU_RUNNER.exec_on_all("rake db:migrate")
      HEROKU_RUNNER.restart
    end

    # NOTE: The following commands require the use of the heroku gem and not the heorku-api.
    # Need to address these commands later.
    # desc "Pulls the database from heroku and stores it into db/dumps/"
    # task :pull do
    #   HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
    #     system_with_echo "heroku pgbackups:capture --app #{app_name}"
    #     dump = `heroku pgbackups --app #{app_name}`.split("\n").last.split(" ").first
    #     system_with_echo "mkdir -p #{HerokuRailsSaas::Config.root}/db/dumps"
    #     file = "#{HerokuRailsSaas::Config.root}/db/dumps/#{app_name}-#{dump}.sql.gz"
    #     url = `heroku pgbackups:url --app #{app_name} #{dump}`.chomp
    #     system_with_echo "wget", url, "-O", file

    #     # TODO: these are a bit distructive...
    #     # system_with_echo "rake db:drop db:create"
    #     # system_with_echo "gunzip -c #{file} | #{HerokuRailsSaas::Config.root}/script/dbconsole"
    #     # system_with_echo "rake jobs:clear"
    #   end
    # end
    
    # desc "Resets a Non Production database"
    # task :reset do
    #   HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
    #     unless heroku_env[HEROKU_RUNNER.regex_for(:production)]
    #       system_with_echo "heroku pg:reset DATABASE_URL --app #{app_name} --confirm #{app_name}"
    #     else
    #       puts "Will not reset the Production database"
    #     end
    #   end
    # end
    
    # desc "Copies a database over a Non Production database"
    # task :copy, [:source] => :reset do |t, args|
    #   HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
    #     raise "missing source" unless HEROKU_CONFIG.app_name_on_heroku(args.source)
          
    #     unless heroku_env[HEROKU_RUNNER.regex_for(:production)]
    #       source_app_name = HEROKU_CONFIG.app_name_on_heroku(args.source)
    #       system_with_echo "heroku pgbackups:restore DATABASE_URL `heroku pgbackups:url --app #{source_app_name}` --app #{app_name} --confirm #{app_name}"
    #     else
    #       puts "Will not overwrite the Production database"
    #     end
    #   end
    # end
  end
end