require 'spec_helper'

describe HerokuRailsSaas::Runner do
  describe "#each_heroku_app" do
    it "should return all apps in all environments" do
      config_files = {:default => config_path("heroku-config.yml"), :apps => [config_path("awesomeapp.yml"), config_path("mediocreapp.yml")]}
      config = HerokuRailsSaas::Config.new(config_files)
      runner = described_class.new(config)
      runner.all_environments
      runner.each_heroku_app {}.should == ["awesomeapp:production", "awesomeapp:staging", "mediocreapp:development"]
    end

    it "should not return a production app if @environment is not specified and there's only one app" do
      config_files = {:default => config_path("heroku-config.yml"), :apps => [config_path("mediocreapp.yml")]}
      config = HerokuRailsSaas::Config.new(config_files)
      runner = described_class.new(config)
      runner.instance_variable_set("@environments", [])
      lambda { runner.each_heroku_app }.should raise_error(SystemExit)
    end
  end

  context "Methods" do
    let(:client) { HerokuRailsSaas::HerokuClient.new }

    before(:each) do
      WebMock.enable!

      config_files = {:default => config_path("heroku-config.yml"), :apps => [config_path("awesomeapp.yml")]}
      config = HerokuRailsSaas::Config.new(config_files)
      @runner = described_class.new(config)
      @runner.stub!(:heroku).and_return(client)
    end

    after(:each) do
      WebMock.reset!
      WebMock.disable!
    end

    describe "#setup_app" do
      it "should create a new app for 'awesomeapp:production'"do
        stub_request(:get, "https://api.heroku.com/apps").to_return(:body => [].to_json, :status => 200)
        stub_request(:post, /.*api\.heroku\.com\/apps.*/).to_return(:body => {}.to_json, :status => 202)

        @runner.add_app("awesomeapp:production")
        @runner.setup_app
      end
    end

    describe "#setup_stack" do
    end

    describe "#setup_collaborators" do
    end

    describe "#setup_addons" do
    end

    describe "#setup_config" do
    end

    describe "#setup_domains" do
    end
  end
end