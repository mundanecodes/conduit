require "spec_helper"
require "mock_redis"

module Conduit
  module Middleware
    class TestMiddleware < Base
      def initialize(app, name)
        super(app)
        @name = name
      end

      def call(env)
        env[:calls] ||= []
        env[:calls] << "#{@name}_before"
        result = @app.call(env)
        env[:calls] << "#{@name}_after"
        result
      end
    end

    RSpec.describe "Middleware" do
      describe Chain do
        let(:chain) { Chain.new }

        it "executes middleware in correct order" do
          chain.use TestMiddleware, "first"
          chain.use TestMiddleware, "second"

          env = {}
          chain.call(env) do |e|
            e[:calls] << "app"
            {response: "done"}
          end

          expect(env[:calls]).to eq([
            "first_before",
            "second_before",
            "app",
            "second_after",
            "first_after"
          ])
        end
      end

      describe Logging do
        let(:logger) { double("logger") }
        let(:app) { ->(env) { {response: Response.new(text: "OK"), action: :continue} } }
        let(:middleware) { Logging.new(app, logger:) }

        it "logs requests and responses" do
          expect(logger).to receive(:info).with(/USSD Request/)
          expect(logger).to receive(:info).with(/USSD Response/)

          env = {session_id: "123", msisdn: "254712345678", input: "1"}
          middleware.call(env)
        end
      end

      describe Throttling do
        let(:app) { ->(env) { {response: Response.new(text: "OK"), provider: env[:provider]} } }
        let(:middleware) { Throttling.new(app, max_requests: 2, window: 60) }
        let(:mock_redis) { ::MockRedis.new }  # This is using global MockRedis

        before do
          allow(Conduit.configuration.redis_pool).to receive(:with).and_yield(mock_redis)
        end

        it "allows requests under limit" do
          env = {msisdn: "254712345678"}

          result1 = middleware.call(env)
          result2 = middleware.call(env)

          expect(result1[:response].text).to eq("OK")
          expect(result2[:response].text).to eq("OK")
        end

        it "blocks requests over limit" do
          env = {msisdn: "254712345678"}

          middleware.call(env) # 1
          middleware.call(env) # 2
          result = middleware.call(env) # 3 - should be blocked

          expect(result[:response].text).to include("Too many requests")
          expect(result[:response].action).to eq(:end)
        end
      end
    end
  end
end
