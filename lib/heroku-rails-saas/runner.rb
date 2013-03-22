require 'active_support/core_ext/object/blank'
require 'parallel'

require_relative 'heroku_client'
require_relative 'helper'
require_relative 'displayer'

module HerokuRailsSaas
  class Runner
    extend Forwardable

    DATABASE_REGEX = /heroku-postgresql|shared-database|heroku-shared-postgresql|amazon_rds/
    SHARED_DATABASE_ADDON = "shared-database:5mb"
    CONFIG_DELETE_MARKER = "DELETE"
    LOCAL_CA_FILE = File.expand_path('../../data/cacert.pem', __FILE__)

    class << self
      # Returns an array of :add and :delete deltas respectively.
      def deltas(local, remote)
        [local - remote, remote - local]
      end
    end

    def initialize(config)
      @config = config
      @local_names = []
      @displayer = nil
      @assigned_colors = {}
    end

    def_delegator :@displayer, :labelize

    # App/Environment methods
    #---------------------------------------------------------------------------------------------------------------------
    #
    def heroku
      @heroku ||= HerokuClient.new
    end

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
        _setup_app(local_name, remote_name)
      end
    end

    def setup_stack
      each_heroku_app do |local_name, remote_name|
        remote_stack  = heroku.get_stack(remote_name).select { |stack| stack["current"] }.first["name"]
        local_stack   = @config.stack(local_name)

        if local_stack != remote_stack
          puts "Migrating the app: #{remote_name} to the stack: #{local_stack}"
          heroku.put_stack(remote_name, local_stack)
        end
      end
    end

    def setup_collaborators
      each_heroku_app do |local_name, remote_name|
        _setup_collaborators(local_name, remote_name)
      end
    end

    def setup_addons
      each_heroku_app do |local_name, remote_name|
        _setup_addons(local_name, remote_name)
      end
    end

    def setup_config
      each_heroku_app do |local_name, remote_name|
        _setup_config(local_name, remote_name)
      end
    end

    def setup_domains
      each_heroku_app do |local_name, remote_name|
        _setup_domains(local_name, remote_name)
      end
    end

    # Action methods
    #---------------------------------------------------------------------------------------------------------------------
    #
    def deploy
      require 'pty'

      Rake::Task["heroku:before_deploy"].invoke

      deploy_branch = prompt_for_branch

      each_heroku_app do |local_name, remote_name|
        @displayer.labelize("Deploying to #{remote_name}...")

        configs = @config.config(local_name)

        Rake::Task["heroku:before_each_deploy"].reenable
        Rake::Task["heroku:before_each_deploy"].invoke(local_name, remote_name, configs)

        begin
          raise "Server not setup run `rake #{local_name} heorku:setup`" if _setup_app?(remote_name)

          repo = heroku.get_app(remote_name)["git_url"]

          # The use of PTY here is because we can't depend on the external process 'git' to flush its
          # buffered output to STDOUT, using PTY we can mimic a terminal and trick 'git' into periodically flushing
          # it's output. 
          # NOTE: The process bar in 'git' doesn't render correct since it tries to re-render the same line while
          # other proceess are trying to do the same.
          # ^0 is required so git dereferences the tag into a commit SHA (else Heroku's git server will throw up)
          # See https://github.com/TerraCycleUS/heroku-rails-saas/commit/25cbcd3d79fe74e4e54297df1022a39bdd104668
          PTY.spawn("git push #{repo} --force #{deploy_branch}^0:refs/heads/master") do |read_io, _, pid|
            begin
              read_io.sync = true
              read_io.each { |line| @displayer.labelize(line) }
              Process.wait(pid)
            rescue Errno::EIO
            end
          end

          if continue = $?.exitstatus
            _maintenance(true, remote_name)
            _setup_collaborators(local_name, remote_name)
            _setup_addons(local_name, remote_name)
            _setup_domains(local_name, remote_name)
            _setup_config(local_name, remote_name)
            _migrate(remote_name)
            _scale(local_name, remote_name)
            _restart(remote_name)
            _maintenance(false, remote_name)
          end
        rescue Interrupt
          @displayer.labelize("!!! Interrupt issued stopping deployment")
        rescue Exception => error
          @displayer.labelize("!!! Error deploying: #{Helper.red(error.message)}")
          continue = false
        ensure
          Rake::Task["heroku:ensure_each_deploy"].reenable
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
      result = heroku.post_ps(remote_name, command)
      @displayer.labelize(Helper.green(result["command"]))
    end

    def apps
      each_heroku_app do |local_name, remote_name|
        repo = heroku.get_app(remote_name)["git_url"]
        puts "#{Helper.red(local_name)} maps to the Heroku app #{Helper.yellow(remote_name)}:"
        puts "  #{Helper.green(repo)}"
        puts
      end
    end

    # Implementation from https://raw.github.com/heroku/heroku/master/lib/heroku/command/apps.rb to be consistent with our output.
    # See Helper#styled_hash for further implemention details.
    def info
      each_heroku_app do |_, remote_name|
        app_data = heroku.get_app(remote_name)

        addons = heroku.get_addons(remote_name).map { |addon| addon['name'] }.sort
        collaborators = heroku.get_collaborators(remote_name).map { |collaborator| collaborator['email'] }.sort
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

        Helper.styled_hash(data, @displayer)
      end  
    end

    def maintenance(toggle)
      each_heroku_app do |_, remote_name|
        _maintenance(toggle, remote_name)
      end 
    end

    def restart
      each_heroku_app do |_, remote_name|
        _restart(remote_name)
      end
    end

    def scale
      each_heroku_app do |local_name, remote_name|
        _scale(local_name, remote_name)
      end
    end

    def logs
      each_heroku_app do |_, remote_name|
        _logs(remote_name)
      end
    end

    # NOTE: This doesn't work with more than one environment. My guess is that each process triggers STDIN to flush
    # its buffer causing it to act very strange. A possible solution is to have a master process (or the current rake
    # process) to control the flow of input data via an IO pipe.
    def console
      require 'rendezvous'

      each_heroku_app do |_, remote_name|
        _console(remote_name)
      end
    end

    # Helper methods
    #---------------------------------------------------------------------------------------------------------------------
    #
    # Cycles through each heroku app and yield the local app name and the heroku app name. This will fork and create another 
    # child process for each heorku app.
    def each_heroku_app
      process_heroku_command do |local_names|
        $stdout.sync = true # Sync up the bufferred output.

        # Preload the colors before we parallelize any commands.
        local_names.each do |local_name|
          @assigned_colors[local_name] ||= Helper::COLORS[@assigned_colors.size % Helper::COLORS.size]
        end

        # Performs work in 4 processes, each process is tasked the same command but for a different 
        # heroku environment. 
        # We use processes to get around the GIL/GVL issues. 
        Parallel.each(local_names, :in_processes => 4) do |local_name|
          remote_name = @config.heroku_app_name(local_name)
          @displayer = Displayer.new(remote_name, @assigned_colors[local_name])
          yield(local_name, remote_name)
        end
      end
    end

    # Internal methods
    #---------------------------------------------------------------------------------------------------------------------
    #
  private
    def _setup_app(local_name, remote_name)
      if _setup_app?(remote_name)
        params = {'name' => remote_name}
        region = @config.region(local_name)

        @displayer.labelize("Creating Heroku app: #{Helper.green(remote_name)}")

        if region.present?
          params.merge!('region' => region)
          @displayer.labelize("\t Region: #{Helper.green(region)}")
        end

        heroku.post_app(params)
      end
    end

    def _setup_app?(remote_name)
      !heroku.get_apps.any? { |apps| apps["name"] == remote_name }
    end

    def _setup_collaborators(local_name, remote_name)
      @displayer.labelize("Setting collaborators... ")
      
      remote_collaborators = heroku.get_collaborators(remote_name).map { |collaborator| collaborator["email"] }
      local_collaborators  = @config.collaborators(local_name)

      add_collaborators, delete_collaborators = self.class.deltas(local_collaborators, remote_collaborators)
      apply(remote_name, add_collaborators, "post_collaborator", "Adding collaborator(s):")
      apply(remote_name, delete_collaborators, "delete_collaborator", "Deleting collaborator(s):")
    end

    def _setup_addons(local_name, remote_name)
      @displayer.labelize("Setting addons... ")

      remote_addons = heroku.get_addons(remote_name).map { |addon| addon["name"] }
      local_addons  = @config.addons(local_name)

      # Requires at the minimum a shared database.
      local_addons << SHARED_DATABASE_ADDON unless local_addons.any? {|x| x[DATABASE_REGEX] }

      add_addons, delete_addons = self.class.deltas(local_addons, remote_addons)
      apply(remote_name, add_addons, "post_addon", "Adding addon(s):")
      apply(remote_name, delete_addons, "delete_addon", "Deleting addon(s):")
    end

    def _setup_config(local_name, remote_name)
      @displayer.labelize("Setting config... ")

      remote_configs = heroku.get_config_vars(remote_name)
      local_configs = @config.config(local_name)

      delete_config_keys = []
      add_configs = local_configs.delete_if do |key, value| 
        if value == CONFIG_DELETE_MARKER
          delete_config_keys << key
        elsif remote_configs.has_key?(key) && remote_configs[key] == value
          true
        end 
      end
      perform_delete = delete_config_keys.present? && 
                       remote_configs.keys.any? { |key| delete_config_keys.include?(key) }
      
      if add_configs.present?
        @displayer.labelize("Adding config(s):")
        add_configs.each do |key, value|
          if value.include?("\n")
            configs_values = value.split("\n")
            @displayer.labelize("#{key.rjust(25)}: #{configs_values.shift}")
            configs_values.each { |v| @displayer.labelize("#{''.rjust(25)} #{v}") }
          else  
            @displayer.labelize("#{key.rjust(25)}: #{value}")
          end
        end
        heroku.put_config_vars(remote_name, add_configs)
      end

      if perform_delete
        @displayer.labelize("Deleting config(s):")
        delete_config_keys.each do |key| 
          @displayer.labelize("#{key.rjust(25)}: #{remote_configs[key]}")
          heroku.delete_config_var(remote_name, key) 
        end
      end
    end

    def _setup_domains(local_name, remote_name)
      @displayer.labelize("Setting domains... ")

      remote_domains = heroku.get_domains(remote_name).map { |domain| domain["domain"] }
      local_domains  = @config.domains(local_name)
      add_domains, delete_domains = self.class.deltas(local_domains, remote_domains)

      apply(remote_name, add_domains, "post_domain", "Adding domain(s):")
      apply(remote_name, delete_domains, "delete_domain", "Deleting domain(s):")
    end

    def _maintenance(toggle, remote_name)
      value   = toggle ? '1' : 0
      display = toggle ? Helper.green("ON") : Helper.red("OFF")
      @displayer.labelize("Maintenance mode #{display}")
      heroku.post_app_maintenance(remote_name, value)
    end

    def _restart(remote_name)
      heroku.post_ps_restart(remote_name)
      @displayer.labelize("Restarting... #{Helper.green('OK')}")
    end

    def _migrate(remote_name)
      exec(remote_name, "rake db:migrate")
    end

    def _scale(local_name, remote_name)
      scaling = @config.scale(local_name)
      types = scaling.keys
      
      # Clock must be the last process to scale because it could require a worker dyno to be present
      # since it can trigger a scheduling of a background job immediately after its state is up.
      types << types.delete("clock")
      types.each { |type| heroku.post_ps_scale(remote_name, type, scaling[type]) }
      @displayer.labelize("Scaling ... #{Helper.green('OK')}")
    end

    def _logs(remote_name)
      url = heroku.get_logs(remote_name, {:tail => 1})
      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)

      if uri.scheme == 'https'
        http.use_ssl = true
        if ENV["HEROKU_SSL_VERIFY"] == "disable"
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        else
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.ca_file = LOCAL_CA_FILE
          http.verify_callback = lambda do |preverify_ok, ssl_context|
            if (!preverify_ok) || ssl_context.error != 0
              @displayer.labelize("WARNING: Unable to verify SSL certificate for #{host}\nTo disable SSL verification, run with HEROKU_SSL_VERIFY=disable")
            end
            true
          end
        end
      end

      http.read_timeout = 60 * 60 * 24

      begin
        http.start do
          http.request_get(uri.path + (uri.query ? "?" + uri.query : "")) do |request|
            request.read_body do |chunk|
              chunk.split("\n").each { |line| @displayer.labelize(line) }
            end
          end
        end
      rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
        @displayer.labelize("Could not connect to logging service")
      rescue Timeout::Error, EOFError
        @displayer.labelize("\nRequest timed out")
      end
    end

    def _console(remote_name)
      data = heroku.post_ps(remote_name, 'console', {:attach => true})

      Rendezvous.start(:url => data['rendezvous_url'])
    end

    # Prompt for a branch tag if any of the environments being deploy to is production grade.
    # This serves as a sanity check against deploy directly to production environments. 
    def prompt_for_branch
      deploy_branch = nil

      if @local_names.any? {|local_name| local_name[regex_for(:production)] }
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

        deploy_branch = target_tag
      else
        deploy_branch = `git branch`.scan(/^\* (.*)\n/).flatten.first.to_s
        
        if deploy_branch.empty?
          puts "Unable to determine the current git branch, please checkout the branch you'd like to deploy."
          exit(1) 
        end
      end

      deploy_branch
    end

    # Checks to see if there is at least one environment indicated to run commands against.
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
        @displayer.labelize(message)
        settings.each do |setting|
          @displayer.labelize("\t#{setting}")
          heroku.__send__(method.to_sym, app, setting)
        end
      end
    end

    # Returns a regex to look for a specific type of an environment.
    def regex_for(environment)
      match = case environment
        when :production then "production|prod|live"
        when :staging    then "staging|stage"
      end
      Regexp.new("#{@config.class::SEPERATOR}(#{match})")
    end
  end
end