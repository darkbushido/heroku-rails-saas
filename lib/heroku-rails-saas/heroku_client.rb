require 'heroku-api'
require 'netrc'

require_relative 'helper'

module HerokuRailsSaas
  class HerokuClient
    HEROKU_API_HOST = "api.heroku.com"

    attr_accessor :user, :heroku

    def initialize
      @user, @api_token = netrc[HEROKU_API_HOST]
      @heroku = Heroku::API.new(:api_key => @api_token)
    end

    def method_missing(method_name, *args, &block)
      begin
        response = @heroku.__send__(method_name.to_sym, *args, &block)
        JSON.parse(response.to_json)["body"]
      rescue Heroku::API::Errors::ErrorWithResponse => error
        message = error.response.body ? JSON.parse(error.response.body)["error"] : ""
        status = error.response.headers["Status"]

        raise <<-OUTPUT
              #{Helper.red(error.class)}:
                Status: #{Helper.yellow(status)}
                Message: #{message}
              OUTPUT
      end
    end

  private
    def netrc # :nodoc:
      @netrc ||= begin
        File.exists?(netrc_path) && Netrc.read(netrc_path)
      rescue => error
        raise ".netrc missing or no entry found. Try `heroku auth:login`"
      end
    end

    def netrc_path # :nodoc:
      default = Netrc.default_path
      encrypted = default + ".gpg"
      if File.exists?(encrypted)
        encrypted
      else
        default
      end
    end
  end
end