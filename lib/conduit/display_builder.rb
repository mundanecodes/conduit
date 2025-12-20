module Conduit
  class DisplayBuilder
    attr_reader :parts

    def initialize
      @parts = []
    end

    def header(*lines)
      @parts << lines.join("\n")
      @parts << "" # Add blank line after header
    end

    def text(content)
      @parts << content
    end

    def menu(&block)
      menu_builder = MenuBuilder.new
      menu_builder.instance_eval(&block)
      @parts << menu_builder.to_s
    end

    def blank_line
      @parts << ""
    end

    def to_s
      @parts.join("\n")
    end
  end

  class MenuBuilder
    def initialize
      @options = []
    end

    def option(number, text)
      @options << "#{number}. #{text}"
    end

    def back_option(text = "Back")
      @options << "0. #{text}"
    end

    def home_option(text = "Main Menu")
      @options << "00. #{text}"
    end

    def exit_option(text = "Exit")
      @options << "000. #{text}"
    end

    def to_s
      @options.join("\n")
    end
  end
end
