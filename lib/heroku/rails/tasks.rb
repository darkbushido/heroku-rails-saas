require 'heroku-rails-saas'

HEROKU_CONFIG_FILE = File.join(HerokuRailsSaas::Config.root, 'config', 'heroku.yml')
HEROKU_APP_SPECIFIC_CONFIG_FILES = Dir.glob("#{File.join(HerokuRailsSaas::Config.root, 'config', 'heroku')}/*.yml")
HEROKU_CONFIG = HerokuRailsSaas::Config.new({:default => HEROKU_CONFIG_FILE, :apps => HEROKU_APP_SPECIFIC_CONFIG_FILES})
HEROKU_RUNNER = HerokuRailsSaas::Runner.new(HEROKU_CONFIG)

# create all the environment specific tasks
(HEROKU_CONFIG.apps).each do |app, hsh|
  hsh.each do |env, heroku_env|
    app_name = HerokuRailsSaas::Config.app_name(app, env)
    desc "Select #{app_name} Heroku app for later commands"
    task app_name do
      # callback switch_environment
      @heroku_app = {:env => heroku_env, :app_name => app_name}
      Rake::Task["heroku:switch_environment"].reenable
      Rake::Task["heroku:switch_environment"].invoke

      HEROKU_RUNNER.add_environment(app_name)
    end
  end
end

desc 'Select all Heroku apps for later command (production must be explicitly declared)'
task :all do
  HEROKU_RUNNER.all_environments(true)
end

(HEROKU_CONFIG.all_environments).each do |env|
  desc "Select all Heroku apps in #{env} environment"
  task "all:#{env}" do
    HEROKU_RUNNER.environments(env)
  end
end

namespace :heroku do
  def system_with_echo(*args)
    HEROKU_RUNNER.system_with_echo(*args)
  end

  desc 'Add git remotes for all apps in this project'
  task :remotes do
    HEROKU_RUNNER.all_environments
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      system_with_echo("git remote add #{app_name} #{repo}")
    end
  end

  desc 'Lists configured apps'
  task :apps do
    HEROKU_RUNNER.all_environments
    puts "\n"
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      puts "#{heroku_env} maps to the Heroku app #{app_name} located at:"
      puts "  #{repo}"
      puts
    end
  end

  desc "Get remote server information on the heroku app"
  task :info do
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      system_with_echo "heroku info --app #{app_name}"
      puts "\n"
    end
  end

  desc "Deploys, migrates and restarts latest git tag"
  task :deploy => "heroku:before_deploy" do |t, args|
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      puts "\n\nDeploying to #{app_name}..."
      # set the current heroku_app so that callbacks can read the data
      @heroku_app = {:env => heroku_env, :app_name => app_name, :repo => repo}
      Rake::Task["heroku:before_each_deploy"].reenable
      Rake::Task["heroku:before_each_deploy"].invoke(app_name)

      cmd = HEROKU_CONFIG.cmd(heroku_env)

      if heroku_env[HEROKU_RUNNER.regex_for(:production)]
        all_tags = `git tag`
        target_tag = `git describe --tags --abbrev=0`.chomp # Set latest tag as default

        begin
          puts "\nGit tags:"
          puts all_tags
          print "\nPlease enter a tag to deploy (or hit Enter for \"#{target_tag}\"): "
          input_tag = STDIN.gets.chomp
          if input_tag.present?
            if all_tags[/^#{input_tag}\n/].present?
              target_tag = input_tag
              invalid = false
            else
              puts "\n\nInvalid git tag!"
              invalid = true
            end
          end
        end while invalid
        puts "Unable to determine the tag to deploy." and exit(1) if target_tag.empty?
        to_deploy = "#{target_tag}^{}"
      else
        to_deploy = `git branch`.scan(/^\* (.*)\n/).flatten.first.to_s
        puts "Unable to determine the current git branch, please checkout the branch you'd like to deploy." and exit(1) if to_deploy.empty?
      end

      @git_push_arguments ||= []
      @git_push_arguments << '--force'

      system_with_echo "git push #{repo} #{@git_push_arguments.join(' ')} #{to_deploy}:master"

      system_with_echo "heroku maintenance:on --app #{app_name}"

      Rake::Task["heroku:setup:config"].invoke
      system_with_echo "#{cmd} rake --app #{app_name} db:migrate && heroku restart --app #{app_name}"

      system_with_echo "heroku maintenance:off --app #{app_name}"

      Rake::Task["heroku:after_each_deploy"].reenable
      Rake::Task["heroku:after_each_deploy"].invoke(app_name)
      puts "\n"
    end
    Rake::Task["heroku:after_deploy"].invoke
  end

  # Callback before all deploys
  task :before_deploy do
  end

  # Callback after all deploys
  task :after_deploy do
  end

  # Callback before each deploy
  task :before_each_deploy, [:app_name] do |t,args|
  end

  # Callback after each deploy
  task :after_each_deploy, [:app_name] do |t,args|
  end

  # Callback for when we switch environment
  task :switch_environment do
  end

  desc "Force deploys, migrates and restarts latest code"
  task :force_deploy do
    @git_push_arguments ||= []
    @git_push_arguments << '--force'
    Rake::Task["heroku:deploy"].execute
  end

  desc "Captures a bundle on Heroku"
  task :capture do
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      system_with_echo "heroku bundles:capture --app #{app_name}"
    end
  end

  desc "Opens a remote console"
  task :console do
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      cmd = HEROKU_CONFIG.cmd(heroku_env)
      system_with_echo "#{cmd} console --app #{app_name}"
    end
  end

  desc "Shows the Heroku logs"
  task :logs do
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      system_with_echo "heroku logs --app #{app_name}"
    end
  end

  desc "Restarts remote servers"
  task :restart do
    HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
      system_with_echo "heroku restart --app #{app_name}"
    end
  end

  desc "Scales heroku processes"
  task :scale do
    HEROKU_RUNNER.scale
  end

  namespace :setup do

    desc "Creates the apps on Heroku"
    task :apps do
      HEROKU_RUNNER.setup_apps
    end

    desc "Setup the Heroku stacks from heroku.yml config"
    task :stacks do
      HEROKU_RUNNER.setup_stacks
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

  desc "Setup Heroku deploy environment from heroku.yml config"
  task :setup => [
    "heroku:setup:apps",
    "heroku:setup:stacks",
    "heroku:setup:collaborators",
    "heroku:setup:config",
    "heroku:setup:addons",
    "heroku:setup:domains",
  ]

  namespace :db do
    desc "Migrates and restarts remote servers"
    task :migrate do
      HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
        cmd = HEROKU_CONFIG.cmd(heroku_env)
        system_with_echo "#{cmd} rake --app #{app_name} db:migrate && heroku restart --app #{app_name}"
      end
    end

    desc "Pulls the database from heroku and stores it into db/dumps/"
    task :pull do
      HEROKU_RUNNER.each_heroku_app do |heroku_env, app_name, repo|
        system_with_echo "heroku pgdumps:capture --app #{app_name}"
        dump = `heroku pgdumps --app #{app_name}`.split("\n").last.split(" ").first
        system_with_echo "mkdir -p #{HerokuRailsSaas::Config.root}/db/dumps"
        file = "#{HerokuRailsSaas::Config.root}/db/dumps/#{dump}.sql.gz"
        url = `heroku pgdumps:url --app #{app_name} #{dump}`.chomp
        system_with_echo "wget", url, "-O", file

        # TODO: these are a bit distructive...
        # system_with_echo "rake db:drop db:create"
        # system_with_echo "gunzip -c #{file} | #{HerokuRailsSaas::Config.root}/script/dbconsole"
        # system_with_echo "rake jobs:clear"
      end
    end
  end
end