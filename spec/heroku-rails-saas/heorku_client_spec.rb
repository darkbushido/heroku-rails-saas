require 'spec_helper'

describe HerokuRailsSaas::HerokuClient do
  it "should raise StandardError when there is no .netrc" do
    File.stub!(:exists?).and_return(false)
    lambda { described_class.new }.should raise_error(StandardError)
  end

  it "should obtain a user and api_token when there is a .netrc" do
    netrc_pathname = config_path("example.netrc").to_s
    File.chmod(0600, netrc_pathname)
    fixture_netrc = Netrc.read(netrc_pathname)
    Netrc.should_receive(:read).and_return(fixture_netrc)
    File.stub!(:exists?).and_return(true)

    client = described_class.new
    client.api_token.should == "THIS_IS_YOU_API_TOKEN"
    client.user.should == "user@example.com"
  end

  context "Making Heroku calls" do
    before(:each) do
      WebMock.enable!

      netrc_pathname = config_path("example.netrc").to_s
      File.chmod(0600, netrc_pathname)
      fixture_netrc = Netrc.read(netrc_pathname)
      Netrc.should_receive(:read).and_return(fixture_netrc)
      File.stub!(:exists?).and_return(true)

      @client = described_class.new
    end

    after(:each) do
      WebMock.reset!
      WebMock.disable!
    end

    it "should return the output when making a valid API call" do
      response = [{"id" => 1000010, "name" => "awesomeapp-staging", "dynos" => 1, "workers" => 0, 
            "repo_size" => 41218048, "slug_size" => 34458496, "stack" => "cedar"},
            {"id" => 1000010, "name" => "awesomeapp", "dynos" => 1, "workers" => 0, 
            "repo_size" => 41218048, "slug_size" => 34458496, "stack" => "cedar"}]
      stub_request(:any, /.*heroku.*/).to_return(:body => response.to_json, :status => 200)
      @client.get_apps.should == response
    end

    it "should raise RuntimeError when making a invalid API call" do
      response = {"id" => "forbidden", "error" => "You do not have permission to provision paid resources for awesomeapp-staging.\\nOnly the app owner, admin@awesomeapp.com, can do that."}
      stub_request(:any, /.*heroku.*/).to_return(:status => 403, :body => response.to_json)
      lambda { @client.post_addon("awesomeapp-staging", "memcache:250mb") }.should raise_error(RuntimeError)
    end

    it "should raise NoMethodError when making a non-exisiting API call" do
      lambda { @client.non_existing_api_call }.should raise_error(NoMethodError)
    end
  end
end