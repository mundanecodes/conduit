module Conduit
  module Middleware
    class Throttling < Base
      def initialize(app, max_requests: 10, window: 60)
        super(app)
        @max_requests = max_requests
        @window = window
      end

      def call(env)
        msisdn = env[:msisdn]
        return @app.call(env) unless msisdn

        key = "throttle:#{msisdn}"
        count = increment_counter(key)

        if count > @max_requests
          {
            response: Conduit::Response.new(
              text: "Too many requests. Please try again later.",
              action: :end
            ),
            provider: env[:provider]
          }
        else
          @app.call(env)
        end
      end

      private

      def increment_counter(key)
        Conduit.configuration.redis_pool.with do |redis|
          count = redis.incr(key)
          redis.expire(key, @window) if count == 1
          count
        end
      end
    end
  end
end
