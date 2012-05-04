require 'spec_helper'

module HerokuRailsSaas
  describe Config do
    before(:each) do
      config_files = {:default => config_path("heroku-config.yml"), :apps => [config_path("awesomeapp.yml"), config_path("mediocreapp.yml")]}
      @config = Config.new(config_files)
    end

    it "should read the configuration file" do
      @config.settings.should_not be_empty
    end

    describe "#apps" do
      it "should return the list of apps defined" do
        @config.apps.should have(2).apps
        @config.apps.should include("awesomeapp")
        @config.apps.should include("mediocreapp")
      end
    end

    describe "#app_names" do
      it "should return the list of apps defined" do
        @config.app_names.should have(2).names
        @config.apps.should include("awesomeapp")
        @config.apps.should include("mediocreapp")
      end
    end

    describe "#app_environments" do
      it "should return a list of the environments defined" do
        @config.app_environments.should have(3).environments
        @config.app_environments.should include("awesomeapp:production")
        @config.app_environments.should include("awesomeapp:staging")
        @config.app_environments.should include("awesomeapp:staging")
      end
    end

    describe "#stack" do
      it "should return the associated stack for awesomeapp:staging" do
        @config.stack("awesomeapp:staging").should == "bamboo-ree-1.8.7"
      end

      it "should return the default stack for awesomeapp:production" do
        @config.stack("awesomeapp:production").should == "bamboo-mri-1.9.2"
      end

      it "should default to the all setting if not explicitly defined" do
        @config.stack("mediocreapp").should == "bamboo-mri-1.9.2"
      end
    end

    describe "#config" do
      context "staging environment" do
        before(:each) do
          @config = @config.config("awesomeapp:staging")
        end
        it "should include configs defined in 'staging'" do
          @config["STAGING_CONFIG"].should == "special-staging"
        end

        it "should include configs defined in 'all'" do
          @config["BUNDLE_WITHOUT"].should == "test:development"
        end

        it "should use configs defined in 'staging' ahead of configs defined in 'all'" do
          @config["CONFIG_VAR1"].should == "config1-staging"
        end
      end
    end

    describe "#collaborators" do
      context "awesomeapp:staging" do
        before(:each) do
          @collaborators = @config.collaborators('awesomeapp:staging')
        end

        it "should include the collaborators defined in 'all'" do
          @collaborators.should include('all-user1@somedomain.com')
          @collaborators.should include('all-user2@somedomain.com')
          @collaborators.should have(3).collaborators
        end

        it "should include collaborators defined in 'staging'" do
          @collaborators.should include('staging-user@somedomain.com')
        end

        it "should not include collaborators defined in 'production'" do
          @collaborators.should_not include('production-user@somedomain.com')
        end
      end

      context "mediocreapp:development" do
        before(:each) do
          @collaborators = @config.collaborators('mediocreapp:development')
        end

        it "should include the collaborators defined in 'all'" do
          @collaborators.should include('all-user1@somedomain.com')
          @collaborators.should include('all-user2@somedomain.com')
          @collaborators.should have(3).collaborators
        end

        it "should include collaborators defined in 'development'" do
          @collaborators.should include('mediocre-user@example.com')
        end

        it "should not include collaborators defined other apps" do
          @collaborators.should_not include("staging-user@somedomain.com")
        end
      end
    end

    describe "#domains" do
      context "staging environment" do
        before(:each) do
          @domains = @config.domains('awesomeapp:staging')
        end

        it "should include the domains defined in 'staging'" do
          @domains.should include('staging.awesomeapp.com')
        end

        it "should not include the domains defined in 'production'" do
          @domains.should_not include('awesomeapp.com')
          @domains.should_not include('www.awesomeapp.com')
        end
      end

      context "production environment" do
        it "should include the domains defined in 'production'" do
          @domains = @config.domains('awesomeapp:production')
          @domains.should include('awesomeapp.com')
          @domains.should include('www.awesomeapp.com')
        end
      end
    end

    describe "#addons" do
      context "staging environment" do
        before(:each) do
          @addons = @config.addons('awesomeapp:staging')
        end

        it "should include addons defined in 'all'" do
          @addons.should include('scheduler:standard')
          @addons.should include('newrelic:bronze')
        end

        it "should not include addons defined in 'production'" do
          @addons.should_not include('ssl:piggyback')
        end
      end
    end

    describe "#scale" do
      context "mediocrapp" do
        it "should include the scaling settings defined in 'all'" do
          @scale = @config.scale('mediocreapp')
          @scale['web'].should_not be_nil
          @scale['worker'].should_not be_nil
          @scale['web'].should eql 1
          @scale['worker'].should eql 0
        end
      end

      context "staging environment" do
        it "should include the scaling settings defined in 'staging'" do
          @scale = @config.scale('awesomeapp:staging')
          @scale['web'].should_not be_nil
          @scale['worker'].should_not be_nil
          @scale['web'].should eql 2
          @scale['worker'].should eql 1
        end
      end

      context "production environment" do
        it "should include the scaling settings defined in 'production'" do
          @scale = @config.scale('awesomeapp:production')
          @scale['web'].should_not be_nil
          @scale['worker'].should_not be_nil
          @scale['web'].should eql 3
          @scale['worker'].should eql 2
        end
      end
    end

  end
end