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
      @validations = []
      @on_valid_block = nil
      @on_invalid_block = nil

      instance_eval(&) if block_given?
    end

    def display(text = nil, &block)
      if block
        @display_block = lambda do |session|
          # Try to execute block in DisplayBuilder context
          builder = DisplayBuilder.new
          result = builder.instance_exec(session, &block)
          
          # If block returns a string, use that (old style)
          # Otherwise, use the builder's accumulated content (new DSL style)
          if result.is_a?(String)
            result
          else
            builder.to_s
          end
        end
      else
        @display_block = ->(_) { text }
      end
    end

    def validates(validator_name = nil, *args, **options, &custom_validator)
      if custom_validator
        # Custom validator block
        @validations << custom_validator
      elsif validator_name.is_a?(Symbol)
        # Built-in validator
        validator = Validator.public_send(validator_name, *args, **options)
        @validations << validator
      elsif validator_name.nil?
        raise ArgumentError, "Must provide either a validator name or a block"
      else
        raise ArgumentError, "Invalid validator: #{validator_name}"
      end
    end

    def on_valid(&block)
      @on_valid_block = block
    end

    def on_invalid(&block)
      @on_invalid_block = block
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

    def handle_input(input, session, flow = nil)
      # Check for exact transition match first (before validations)
      # This allows specific handlers like `on "0"` to override validations
      exact_transition = @transitions[input]
      
      if exact_transition
        return exact_transition.execute(input, session)
      end

      # Check for global back navigation (only if no exact match)
      if input == "0" && session.can_go_back?
        session.go_back
        return nil
      elsif input == "00" && flow
        session.navigate_to(flow.class.initial_state_name)
        return nil
      end

      # Run validations if any are defined
      if @validations.any?
        validation_error = run_validations(input, session, flow)

        if validation_error
          # Validation failed
          if @on_invalid_block
            return @on_invalid_block.call(validation_error, session)
          else
            return Response.new(text: validation_error, action: :continue)
          end
        else
          # Validation passed
          if @on_valid_block
            result = @on_valid_block.call(input, session)
            return result if result.is_a?(Response)
          end

          # Continue with normal transition handling
        end
      end

      # Check for catch-all transition
      transition = @transitions[:any]

      return nil unless transition

      transition.execute(input, session)
    end

    private

    def run_callbacks(callbacks, *)
      callbacks.each { |cb| cb.call(*) }
    end

    def run_validations(input, session, flow)
      @validations.each do |validation|
        result = if validation.respond_to?(:call)
          # Lambda or proc
          validation.call(input, session)
        else
          # Method name (symbol)
          flow.send(validation, input, session)
        end

        # If validation returns a string, it's an error message
        return result if result.is_a?(String)
        
        # If validation returns false, use a generic message
        return "Invalid input" if result == false
      end

      nil # No errors
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
