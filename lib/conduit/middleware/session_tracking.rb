module Conduit
  module Middleware
    class SessionTracking < Base
      def call(env)
        session = env[:session]

        if session && session.navigation_stack.empty?
          track_event("session_started", session)
        end

        result = @app.call(env)

        if result[:response]&.end?
          track_event("session_ended", session)
        end

        result
      end

      private

      def track_event(event, session)
        return unless session

        # this could be a call to AppSignal, StatsD ... etc(I'm thinking StatsD)
        Conduit.configuration.logger.info "Track: #{event} for #{session.msisdn}"
      end
    end
  end
end
