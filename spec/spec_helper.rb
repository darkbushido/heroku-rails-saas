require 'heroku-rails-saas'
require 'bundler/setup'


RSpec.configure do |config|
  config.before(:all) do
    @fixture_path = Pathname.new(File.join(File.dirname(__FILE__), "/fixtures"))
    raise "Fixture folder not found: #{@fixture_path}" unless @fixture_path.directory?
    silence_output
  end

  config.after(:all) do
    enable_output
  end

  # returns the file path of a fixture setting file
  def config_path(filename)
    @fixture_path.join(filename)
  end

  # Redirects stderr and stdout to /dev/null.
  def silence_output
    @orig_stderr = $stderr
    @orig_stdout = $stdout

    # redirect stderr and stdout to /dev/null
    $stderr = File.new('/dev/null', 'w')
    $stdout = File.new('/dev/null', 'w')
  end

  # Replace stdout and stderr so anything else is output correctly.
  def enable_output
    $stderr = @orig_stderr
    $stdout = @orig_stdout
    @orig_stderr = nil
    @orig_stdout = nil
  end
end

