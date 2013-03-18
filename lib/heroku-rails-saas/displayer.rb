require_relative 'helper'

module HerokuRailsSaas
  class Displayer
    class << self
      # Prepends a string output with a label consisting of the app name and a color code.    
      def labelize(message="", new_line=true, remote_name, color)
        message = "[ #{Helper.send(color, remote_name)} ] #{message}"
        message = message + "\n" if new_line && message[-1] != "\n"
        $stdout.print(message)
        $stdout.flush
      end
    end

    def initialize(remote_name, color)
      @remote_name = remote_name
      @color = color
    end

    attr_reader :color, :remote_name

    def labelize(message="", new_line=true)
      self.class.labelize(message, new_line, @remote_name, @color)
    end
  end
end