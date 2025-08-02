module Conduit
  module Middleware
    class Logging < Base
      def initialize(app, logger: nil)
        super(app)
        @logger = logger || Conduit.configuration.logger
      end

      def call(env)
        start_time = Time.current

        @logger.info "USSD Request: session_id=#{env[:session_id]} msisdn=#{env[:msisdn]} input=#{env[:input]}"

        result = @app.call(env)

        duration = ((Time.current - start_time) * 1000).round(2)
        @logger.info "USSD Response: session_id=#{env[:session_id]} duration=#{duration}ms action=#{result[:action]}"

        result
      end
    end
  end
end
