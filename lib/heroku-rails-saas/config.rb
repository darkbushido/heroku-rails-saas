require 'active_support/core_ext/object/try'
require 'active_support/core_ext/hash/deep_merge'
require 'erb'

module HerokuRailsSaas
  class Config
    SEPERATOR = ":"

    class << self
      def root
        @heroku_rails_root || ENV["RAILS_ROOT"] || "."
      end

      def root=(root)
        @heroku_rails_root = root
      end

      def local_name(app, env)
        "#{app}#{SEPERATOR}#{env}"
      end

      def extract_environment_from(app_env)
        name, env = app_env.split(SEPERATOR)
        env
      end
      
      def extract_name_from(app_env)
        name, env = app_env.split(SEPERATOR)
        name
      end      
    end

    attr_accessor :settings

    def initialize(config_files)
      self.settings = aggregate_heroku_configs(config_files)
    end

    def apps
      self.settings['apps'] || []
    end

    def app_names
      apps.keys
    end

    def cmd(app_env)
      if self.stack(app_env) =~ /cedar/i
        'heroku run '
      else
        'heroku '
      end
    end

    def rails_cli script
      Rails::VERSION::MAJOR < 3 ? ".script/#{script}" : "rails #{script}"
    end
    
    # Returns the app name on heroku from a string format like so: `app:env`
    # Allows for `rake <app:env> [<app:env>] <command>`
    def heroku_app_name(string)
      app_name, env = string.split(SEPERATOR)
      apps[app_name][env]
    end

    # return all enviromnets in this format app:env
    def app_environments(env_filter="")
      apps.each_with_object([]) do |(app, hsh), arr|
        hsh.each do |env, app_name| 
          arr << self.class.local_name(app, env) if(env_filter.nil? || env_filter.empty? || env == env_filter)
        end
      end
    end

    # return all environments e.g. staging, production, development
    def all_environments
      environments = apps.each_with_object([]) do |(app, hsh), arr|
        hsh.each { |env, app_name| arr << env }
      end
      environments.uniq
    end

    # return the stack setting for a particular app environment
    def stack(app_env)
      name, env = app_env.split(SEPERATOR)
      stacks = self.settings['stacks'] || {}
      stacks[name].try("[]", env) || stacks['all']
    end

    # return a list of domains for a particular app environment
    def domains(app_env)
      name, env = app_env.split(SEPERATOR)
      domains = self.settings['domains'] || {}
      domains[name].try("[]", env) || []
    end

    # pull out the config setting hash for a particular app environment
    def config(app_env)
      app_setting_hash("config", app_env)
    end

    # pull out the scaling setting hash for a particular app environment
    def scale(app_env)
      app_setting_hash("scale", app_env)
    end

    # return a list of collaborators for a particular app environment
    def collaborators(app_env)
      app_setting_array('collaborators', app_env)
    end

    # return a list of addons for a particular app environment
    def addons(app_env)
      app_setting_array('addons', app_env)
    end

    # return the region for a particular app environment
    def region(app_env)
      name, env = app_env.split(SEPERATOR)
      stacks = self.settings['region'] || {}
      stacks[name].try("[]", env) || stacks['all']
    end

  private
    # Add app specific settings to the default ones defined in all for an array listing
    def app_setting_array(setting_key, app_env)
      name, env = app_env.split(SEPERATOR)
      setting = self.settings[setting_key] || {}
      default = setting['all'] || []

      app_settings = Array.wrap(setting[name].try("[]", env))

      # Replace default addons tier with app specific ones.
      addons = (default + app_settings).uniq.each_with_object({}) do |addon, hash|
        name, tier = addon.split(":")
        hash[name] = tier
      end

      addons.to_a.map { |key_value| key_value.join(":") }
    end

    # Add app specific settings to the default ones defined in all for a hash listing
    def app_setting_hash(setting_key, app_env)
      name, env = app_env.split(SEPERATOR)
      config = self.settings[setting_key] || {}
      all = config['all'] || {}

      app_configs = (config[name] && config[name].reject { |k,v| v.class == Hash }) || {}
      # overwrite app settings with the environment specific ones
      merged_environment_configs = app_configs.merge((config[name] && config[name][env]) || {})

      # overwrite all settings with the environment specific ones
      all.merge(merged_environment_configs)
    end

    def parse_yml(config_filepath, options)
      if File.exists?(config_filepath)
        config_hash = YAML.load(ERB.new(File.read(config_filepath)).result)
        config_hash = add_all_namespace(config_hash) if options == :default
        config_hash = add_app_namespace(File.basename(config_filepath, ".yml"), config_hash) if options == :apps
        config_hash
      end
    end

    def add_all_namespace(hsh)
      hsh.each_with_object({}) { |(k,v), h| h[k] = Hash["all" => v] }
    end

    def add_app_namespace(app_name, hsh)
      hsh["apps"] = hsh.delete("env") if hsh.has_key?("env")
      hsh.each_with_object({}) { |(k,v), h| h[k] = Hash[app_name => v] }
    end

    def aggregate_heroku_configs(config_files)
      configs = config_files[:apps].each_with_object({}) { |file, h| h.deep_merge!(parse_yml(file, :apps)) }
      # overwrite all configs with the environment specific ones
      configs.deep_merge!(parse_yml(config_files[:default], :default))
    end
  end
end