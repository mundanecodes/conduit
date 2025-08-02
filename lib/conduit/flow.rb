module Conduit
  class Flow
    class << self
      attr_reader :initial_state_name

      def states
        @states ||= {}
      end

      def initial_state(name)
        @initial_state_name = name
      end

      def state(name, options = {}, &)
        states[name.to_sym] = State.new(name, options, &)
      end
    end

    def initialize
      @states = self.class.states
      @initial_state = self.class.initial_state_name
    end

    def process(session, input = nil)
      # Initialize state if needed
      if session.current_state.nil? || session.current_state == "initial"
        session.current_state = @initial_state
      end

      # Get current state object
      current_state = @states[session.current_state.to_sym]

      unless current_state
        raise InvalidTransition, "State '#{session.current_state}' not found"
      end

      # Process input if provided
      if input.present?
        result = current_state.handle_input(input, session)
        return result if result.is_a?(Response)

        # If state changed, render new state
        if session.current_state != current_state.name
          current_state = @states[session.current_state.to_sym]
        end
      end

      # Render current state
      current_state.render(session)
    end
  end
end
