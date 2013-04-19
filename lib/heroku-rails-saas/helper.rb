require_relative 'displayer'

module HerokuRailsSaas
  module Helper
    COLORS = %w(cyan yellow green magenta red)
    COLOR_CODES = {
      "red"     => 31,
      "green"   => 32,
      "yellow"  => 33,
      "magenta" => 35,
      "cyan"    => 36,
    }
    
    class << self
      COLORS.each do |color|
        define_method(color.to_sym) { |string| colorize(string, COLOR_CODES[color]) }
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
      def styled_hash(hash, displayer)
        max_key_length = hash.keys.map {|key| key.to_s.length}.max + 2
        keys ||= hash.keys.sort {|x,y| x.to_s <=> y.to_s}
        keys.each do |key|
          case value = hash[key]
          when Array
            if value.empty?
              next
            else
              elements = value.sort {|x,y| x.to_s <=> y.to_s}
              displayer.labelize("#{key}: ".ljust(max_key_length), false)
              puts elements[0]
              elements[1..-1].each do |element|
                displayer.labelize("#{' ' * max_key_length}#{element}")
              end
              if elements.length > 1
                displayer.labelize
              end
            end
          when nil
            next
          else
            displayer.labelize("#{key}: ".ljust(max_key_length), false)
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