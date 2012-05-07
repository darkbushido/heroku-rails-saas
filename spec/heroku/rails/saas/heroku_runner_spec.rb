require 'spec_helper'

module HerokuRailsSaas
  describe Runner do
    describe "#each_heroku_app" do
      it "should return all apps in all environments" do
        config_files = {:default => config_path("heroku-config.yml"), :apps => [config_path("awesomeapp.yml"), config_path("mediocreapp.yml")]}
        config = Config.new(config_files)
        runner = Runner.new(config)
        runner.all_environments
        runner.each_heroku_app {}.should == ["awesomeapp:production", "awesomeapp:staging", "mediocreapp:development"]
      end

      it "should not return a production app if @environment is not specified and there's only one app" do
        config_files = {:default => config_path("heroku-config.yml"), :apps => [config_path("mediocreapp.yml")]}
        config = Config.new(config_files)
        runner = Runner.new(config)
        runner.instance_variable_set("@environments", [])
        lambda { runner.each_heroku_app }.should raise_error(SystemExit)
      end
    end
  end
end