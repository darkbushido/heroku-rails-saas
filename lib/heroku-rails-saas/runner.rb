require 'active_support/core_ext/object/blank'

require_relative 'heroku_client'
require_relative 'helper'

module HerokuRailsSaas
  class Runner
    DATABASE_REGEX = /heroku-postgresql|shared-database|heroku-shared-postgresql|amazon_rds/
    SHARED_DATABASE_ADDON = "shared-database:5mb"
    CONFIG_DELETE_MARKER = "DELETE"

    class << self
      # Returns an array of :add and :delete deltas respectively.
      def deltas(local, remote)
        [local - remote, remote - local]
      end
    end

    def initialize(config)
      @config = config
      @local_names = []
      @heroku = HerokuClient.new
      @user = @heroku.user
    end

    # App/Envronment methods
    #---------------------------------------------------------------------------------------------------------------------
    #
    def add_app(local_name)
      @local_names << local_name
    end

    def add_environment(environment)
      @local_names = @config.app_environments(environment)
    end

    # Set filter to true to filter out all production environments.
    def all_environments(filter=false)
      @local_names = @config.app_environments
      filter ? @local_names.reject! { |local_name| local_name[regex_for(:production)] } : @local_names
    end

    # Setup methods
    #---------------------------------------------------------------------------------------------------------------------
    #
    def setup_app
      each_heroku_app do |local_name, remote_name|
        remote_apps = @heroku.get_apps.map { |apps| apps["name"] }

        unless remote_apps.include?(remote_name)
          params = {'name' => remote_name}
          region = @config.region(local_name)

          puts "Creating Heroku app: #{Helper.green(remote_name)}"

          if region.present?
            params.merge!('region' => region)
            puts "\t Region: #{Helper.green(region)}"
          end

          @heroku.post_app(params)
        end
      end
    end

    def setup_stack
      each_heroku_app do |local_name, remote_name|
        remote_stack  = @heroku.get_stack(remote_name).select { |stack| stack["current"] }.first["name"]
        local_stack   = @config.stack(local_name)

        if local_stack != remote_stack
          puts "Migrating the app: #{remote_name} to the stack: #{local_stack}"
          @heroku.put_stack(remote_name, local_stack)
        end
      end
    end

    def setup_collaborators
      each_heroku_app do |local_name, remote_name|
        puts "Setting #{Helper.green('collaborators')}... "
        __setup_collaborators__(local_name, remote_name)
      end
    end

    def setup_addons
      puts "Setting #{Helper.green('addons')}... "
      each_heroku_app do |local_name, remote_name|
        __setup_addons__(local_name, remote_name)
      end
    end

    def setup_config
      puts "Setting #{Helper.green('config')}... "
      each_heroku_app do |local_name, remote_name|
        __setup_config__(local_name, remote_name)
      end
    end

    def setup_domains
      puts "Setting #{Helper.green('domains')}... "
      each_heroku_app do |local_name, remote_name|
        __setup_domains__(local_name, remote_name)
      end
    end

    # Action methods
    #---------------------------------------------------------------------------------------------------------------------
    #
    def deploy
      Rake::Task["heroku:before_deploy"].invoke

      each_heroku_app do |local_name, remote_name|
        puts "Deploying to #{Helper.green(remote_name)}..."

        configs = @config.config(local_name)

        Rake::Task["heroku:before_each_deploy"].reenable
        Rake::Task["heroku:before_each_deploy"].invoke(local_name, remote_name, configs)

        begin
          repo = @heroku.get_app(remote_name)["git_url"]
          deploy_branch = prompt_for_branch(local_name)
          if continue = system("git push #{repo} --force #{deploy_branch}:master")
            __maintenance__(true, remote_name)
            __setup_collaborators__(local_name, remote_name)
            __setup_addons__(local_name, remote_name)
            __setup_domains__(local_name, remote_name)
            __setup_config__(local_name, remote_name)        
            __maintenance__(false, remote_name)
            @heroku.post_ps(remote_name, "rake db:migrate")
          end     
        rescue Exception => error
          puts "ERROR deploying #{Helper.yellow(remote_name)}:"
          puts Helper.red(error.message)
          continue = false
        ensure          Rake::Task["heroku:ensure_each_deploy"].reenable
          Rake::Task["heroku:ensure_each_deploy"].invoke(local_name, remote_name, configs)
        end

        if continue
          Rake::Task["heroku:after_each_deploy"].reenable
          Rake::Task["heroku:after_each_deploy"].invoke(local_name, remote_name, configs)
        end
      end

      Rake::Task["heroku:after_deploy"].invoke
    end

    def exec_on_all(command)
      each_heroku_app do |_, remote_name|
        exec(remote_name, command)
      end
    end

    def exec(remote_name, command)
      result = @heroku.post_ps(remote_name, command)
      puts "#{remote_name}: #{Helper.green(result["command"])}"
    end

    def apps
      each_heroku_app do |local_name, remote_name|
        repo = @heroku.get_app(remote_name)["git_url"]
        puts "#{Helper.red(local_name)} maps to the Heroku app #{Helper.yellow(remote_name)}:"
        puts "  #{Helper.green(repo)}"
        puts
      end
    end

    # Implementation from https://raw.github.com/heroku/heroku/master/lib/heroku/command/apps.rb to be consistent with our output.
    def info
      each_heroku_app do |_, remote_name|
        app_data = @heroku.get_app(remote_name)

        addons = @heroku.get_addons(remote_name).map { |addon| addon['name'] }.sort
        collaborators = @heroku.get_collaborators(remote_name).map { |collaborator| collaborator['email'] }.sort
        collaborators.reject! { |email| email == app_data['owner_email'] }

        data = {:name => remote_name}
        data["Addons"] = addons if addons.present?
        data["Collaborators"] = collaborators
        data["Create Status"] = app_data["create_status"] if app_data["create_status"] && app_data["create_status"] != "complete"
        data["Database Size"] = Helper.format_bytes(app_data["database_size"]) if app_data["database_size"]
        data["Git URL"] = app_data["git_url"]
        data["Database Size"].gsub!('(empty)', '0K') + " in #{quantify("table", app_data["database_tables"])}" if app_data["database_tables"]

        if app_data["dyno_hours"].is_a?(Hash)
          data["Dyno Hours"] = app_data["dyno_hours"].keys.map do |type|
            "%s - %0.2f dyno-hours" % [ type.to_s.capitalize, app_data["dyno_hours"][type] ]
          end
        end

        data["Owner Email"] = app_data["owner_email"]
        data["Region"] = app_data["region"] if app_data["region"]
        data["Repo Size"] = Helper.format_bytes(app_data["repo_size"]) if app_data["repo_size"]
        data["Slug Size"] = Helper.format_bytes(app_data["slug_size"]) if app_data["slug_size"]
        data["Stack"] = app_data["stack"]
        data.merge!("Dynos" => app_data["dynos"], "Workers" => app_data["workers"]) if data["Stack"] != "cedar"
        data["Web URL"] = app_data["web_url"]
        data["Tier"] = app_data["tier"].capitalize if app_data["tier"]

        Helper.styled_hash(data)
      end  
    end

    def maintenance(toggle)
      each_heroku_app do |_, remote_name|
        __maintenance__(toggle, remote_name)
      end 
    end

    def restart
      each_heroku_app do |_, remote_name|
        __restart__(remote_name)
      end
    end

    def scale
      each_heroku_app do |_, remote_name|
        print "Scaling #{remote_name}... "
        scaling = @config.scale(local_name)
        types = scaling.keys
        
        # Clock must be the last process because it could require a worker dyno process present
        # due to it scheduling a job immediately after it is up.
        types << types.delete("clock")
        types.each { |type| @heroku.post_ps_scale(remote_name, type, scaling[type]) }

        puts Helper.green("OK")
      end
    end

    # Helper methods
    #---------------------------------------------------------------------------------------------------------------------
    #

    # Cycles through each heroku app and yield the local app name, the heroku app name, and the git repo url.
    def each_heroku_app
      process_heroku_command do |local_names|
        local_names.each do |local_name|
          remote_name = @config.heroku_app_name(local_name)
          yield(local_name, remote_name)
        end
      end
    end

    def regex_for(environment)
      match = case environment
        when :production then "production|prod|live"
        when :staging    then "staging|stage"
      end
      Regexp.new("#{@config.class::SEPERATOR}(#{match})")
    end

    # Internal methods
    #---------------------------------------------------------------------------------------------------------------------
    #
  protected
    def __setup_collaborators__(local_name, remote_name)
      remote_collaborators = @heroku.get_collaborators(remote_name).map { |collaborator| collaborator["email"] }
      local_collaborators  = @config.collaborators(local_name)

      add_collaborators, delete_collaborators = self.class.deltas(local_collaborators, remote_collaborators)
      apply(remote_name, add_collaborators, "post_collaborator", "Adding collaborator(s):")
      apply(remote_name, delete_collaborators, "delete_collaborator", "Deleting collaborator(s):")
    end

    def __setup_addons__(local_name, remote_name)
      remote_addons = @heroku.get_addons(remote_name).map { |addon| addon["name"] }
      local_addons  = @config.addons(local_name)

      # Requires at the minimum a shared database.
      local_addons << SHARED_DATABASE_ADDON unless local_addons.any? {|x| x[DATABASE_REGEX] }

      add_addons, delete_addons = self.class.deltas(local_addons, remote_addons)
      apply(remote_name, add_addons, "post_addon", "Adding addon(s):")
      apply(remote_name, delete_addons, "delete_addon", "Deleting addon(s):")
    end

    def __setup_config__(local_name, remote_name)
      remote_configs = @heroku.get_config_vars(remote_name)
      local_configs = @config.config(local_name)

      delete_config_keys = []
      add_configs = local_configs.delete_if do |key, value| 
        if value == CONFIG_DELETE_MARKER
          delete_config_keys << key
        elsif remote_configs.has_key?(key) && remote_configs[key] == value
          true
        end 
      end

      if delete_config_keys.present?
        puts "Deleting config(s):"
        delete_config_keys.each do |key| 
          puts "\t#{key}: #{local_configs[:key]}"
          @heroku.delete_config_var(remote_name, key) 
        end
      end

      if add_configs.present?
        puts "Adding config(s):"
        add_configs.each { |key, value| puts "#{key.rjust(25)} = #{value}" }
        @heroku.put_config_vars(remote_name, add_configs)
      end
    end

    def __setup_domains__(local_name, remote_name)
      remote_domains = @heroku.get_domains(remote_name).map { |domain| domain["domain"] }
      local_domains  = @config.domains(local_name)
      add_domains, delete_domains = self.class.deltas(local_domains, remote_domains)

      apply(remote_name, add_domains, "post_domain", "Adding domain(s):")
      apply(remote_name, delete_domains, "delete_domain", "Deleting domain(s):")
    end

    def __maintenance__(toggle, remote_name)
      value   = toggle ? '1' : 0
      display = toggle ? Helper.green("ON") : Helper.red("OFF")
      puts "#{remote_name} maintenance mode #{display}"
      @heroku.post_app_maintenance(remote_name, value)
    end

    def __restart__(remote_name)
      print "Restarting #{remote_name}... "
      @heroku.post_ps_restart(remote_name)
      puts Helper.green("OK")
    end

  private
    def prompt_for_branch(local_name)
      if local_name[regex_for(:production)]
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

        if target_tag.empty?
          puts "Unable to determine the tag to deploy."
          exit(1)
        end

        "#{target_tag}^{}"
      else
        deploy_branch = `git branch`.scan(/^\* (.*)\n/).flatten.first.to_s
        
        if deploy_branch.empty?
          puts "Unable to determine the current git branch, please checkout the branch you'd like to deploy."
          exit(1) 
        end

        deploy_branch
      end
    end

    def process_heroku_command
      if @config.apps.blank?
        puts "\nNo heroku apps are configured. Run: rails generate heroku:config\n\n"
        puts "this will generate a default config/heroku.yml that you should edit"
        puts "and then try running this command again"

        exit(1)
      end

      @local_names = [all_environments(true).try(:first)].compact if @local_names.empty?

      if @local_names.present?
        yield(@local_names)
      else
        puts "\nYou must first specify at least one Heroku app:
          rake <app>:<environment> [<app>:<environment>] <command>
          rake awesomeapp:production restart
          rake demo:staging deploy"

        puts "\n\nYou can use also command all Heroku apps(except production environments) for this project:
          rake all heroku:setup\n"

        exit(1)
      end
    end

    # Apply heroku configurations changes.
    #   app      - name of the remote heroku app.
    #   settings - list to apply method to.
    #   method   - name of the api method to call.
    #   message  - display of what actions are to be performed.
    def apply(app, settings, method, message)
      if settings.present?
        puts "#{message}"
        settings.each do |setting|
          puts "\t#{setting}"
          @heroku.__send__(method.to_sym, app, setting)
        end
      end
    end
  end
end