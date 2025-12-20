module Conduit
  class RequestHandler
    def initialize
      @store = SessionStore.new
      @provider = Providers::AfricasTalking
    end

    def process(raw_params)
      # Parse request using AfricasTalking
      provider = @provider.new(raw_params)
      params = provider.parse_request

      env = {
        params:,
        session_id: params[:session_id],
        msisdn: params[:msisdn],
        service_code: params[:service_code],
        input: params[:input],
        raw_params:,
        provider:
      }

      # Run through middleware chain
      result = Conduit.configuration.middleware.call(env) do |environment|
        process_request(environment)
      end

      # Format response
      result[:provider].format_response(result[:response])
    rescue => e
      Conduit.configuration.logger.error "Error processing request: #{e.message}\n#{e.backtrace.join("\n")}"
      error_response = Response.new(text: "Service temporarily unavailable", action: :end)
      provider.format_response(error_response)
    end

    private

    def process_request(env)
      params = env[:params]

      # Get or create session
      session = @store.get(params[:session_id]) || create_session(params)
      env[:session] = session

      # Check if expired
      if session.expired?
        @store.delete(session.session_id)
        response = Response.new(
          text: "Your session has expired. Please dial again.",
          action: :end
        )
      else
        # Check if there's a pending flow transition from previous request
        if session.data[:pending_flow_transition]
          flow_class_name = session.data[:pending_flow_transition]
          session.data.delete(:pending_flow_transition)

          # Reset session state for new flow
          session.current_state = nil
          
          # Store the current flow for subsequent requests
          session.data[:current_flow] = flow_class_name

          # Instantiate the new flow and process with empty input (display initial state)
          flow = Object.const_get(flow_class_name).new
          response = flow.process(session, "")
        elsif session.data[:current_flow]
          # Continue with the current flow
          flow = Object.const_get(session.data[:current_flow]).new
          response = flow.process(session, params[:input])
        else
          # Get flow for service code (normal flow - first request)
          flow = Router.find_flow(params[:service_code])
          
          # Store the flow class name for subsequent requests
          session.data[:current_flow] = flow.class.name
          
          response = flow.process(session, params[:input])
        end

        # Handle flow transition if next_flow is specified
        if response.transition?
          # Store the next flow class name for the NEXT request
          session.data[:pending_flow_transition] = response.next_flow.name
          # Keep the response text but change action to continue
          response = Response.new(text: response.text, action: :continue)
        end

        # Save or cleanup session
        if response.end?
          save_completed_session(session) if Conduit.configuration.save_sessions
          @store.delete(session.session_id)
        else
          @store.set(session)
        end
      end

      {response:, provider: env[:provider], session:}
    end

    def create_session(params)
      Session.new(
        session_id: params[:session_id],
        msisdn: params[:msisdn],
        service_code: params[:service_code]
      )
    end

    def save_completed_session(session)
      return unless Conduit.configuration.save_sessions

      # Save to database if available
      if defined?(Conduit::SessionRecord)
        begin
          record = Conduit::SessionRecord.from_session(session, completed: true)
          record.save!
          Rails.logger.info "Session saved: #{session.session_id}"
        rescue => e
          Rails.logger.error "Failed to save session: #{e.message}"
        end
      else
        Rails.logger.info "Session completed: #{session.to_h}"
      end
    end
  end
end
