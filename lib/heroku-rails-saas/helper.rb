module HerokuRailsSaas
  module Helper
    class << self
      def red(string)
        colorize(string, 31)
      end

      def green(string)
        colorize(string, 32)
      end

      def yellow(string)
        colorize(string, 33)
      end

      # Implementation from https://github.com/heroku/heroku/blob/master/lib/heroku/helpers.rb for consistency. 
      @@kb = 1024
      @@mb = 1024 * @@kb
      @@gb = 1024 * @@mb
      def format_bytes(amount)
        amount = amount.to_i
        return '(empty)' if amount == 0
        return amount if amount < @@kb
        return "#{(amount / @@kb).round}k" if amount < @@mb
        return "#{(amount / @@mb).round}M" if amount < @@gb
        return "#{(amount / @@gb).round}G"
      end

      # Implementation from https://github.com/heroku/heroku/blob/master/lib/heroku/helpers.rb for consistency.
      def styled_hash(hash)
        max_key_length = hash.keys.map {|key| key.to_s.length}.max + 2
        keys ||= hash.keys.sort {|x,y| x.to_s <=> y.to_s}
        keys.each do |key|
          case value = hash[key]
          when Array
            if value.empty?
              next
            else
              elements = value.sort {|x,y| x.to_s <=> y.to_s}
              print "#{key}: ".ljust(max_key_length)
              puts elements[0]
              elements[1..-1].each do |element|
                puts "#{' ' * max_key_length}#{element}"
              end
              if elements.length > 1
                puts
              end
            end
          when nil
            next
          else
            print "#{key}: ".ljust(max_key_length)
            puts value
          end
        end
      end

    private
      def colorize(string, color_code)
        "\e[#{color_code}m#{string}\e[0m"
      end
    end
  end
end