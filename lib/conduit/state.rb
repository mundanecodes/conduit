module Conduit
  # This behaves like single screen/menu in a USSD flow. Think of it as a "page" in your application.
  #
  class State
    attr_reader :name, :options

    def initialize(name, options = {}, &)
      @name = name.to_sym
      @options = options
      @transitions = {}
      @display_block = nil
      @before_callbacks = []

      instance_eval(&) if block_given?
    end

    def display(text = nil, &block)
      @display_block = block || ->(_) { text }
    end

    def on(input, options = {}, &block)
      @transitions[input.to_s] = Transition.new(input, options, block)
    end

    def on_any(options = {}, &block)
      @transitions[:any] = Transition.new(:any, options, block)
    end

    def before_render(&block)
      @before_callbacks << block
    end

    # Runtime Methods
    def render(session)
      run_callbacks(@before_callbacks, session)

      content = if @display_block
        @display_block.call(session)
      else
        "No content defined for state: #{@name}"
      end

      Response.new(text: content, action: :continue)
    end

    def handle_input(input, session)
      if input == "0" && session.can_go_back?
        session.go_back
        return nil
      elsif input == "00"
        session.navigate_to(@flow.class.initial_state_name)
        return nil
      end

      # Check for exact match first
      transition = @transitions[input] || @transitions[:any]

      return nil unless transition

      transition.execute(input, session)
    end

    private

    def run_callbacks(callbacks, *)
      callbacks.each { |cb| cb.call(*) }
    end
  end

  #  This defines how users move between states based on their input.
  #
  class Transition
    def initialize(matcher, options = {}, block = nil)
      @matcher = matcher
      @to = options[:to]
      @block = block
    end

    def execute(input, session)
      # Execute block if provided
      if @block
        result = @block.call(input, session)
        return result if result.is_a?(Response)
      end

      # Handle navigation
      if @to
        if @to == :back
          session.go_back
        else
          session.navigate_to(@to)
        end
      end

      nil
    end
  end
end
