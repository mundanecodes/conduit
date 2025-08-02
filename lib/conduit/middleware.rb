module Conduit
  module Middleware
    class Base
      def initialize(app, *args, &block)
        @app = app
      end

      delegate :call, to: :@app
    end

    class Chain
      def initialize
        @middlewares = []
      end

      def use(middleware, *args, &block)
        @middlewares << [middleware, args, block]
      end

      def call(env, &final_block)
        chain = final_block || ->(e) { e }

        @middlewares.reverse_each do |(middleware, args, block)|
          previous_chain = chain
          chain = ->(environment) do
            middleware.new(previous_chain, *args, &block).call(environment)
          end
        end

        chain.call(env)
      end

      delegate :clear, to: :@middlewares
    end
  end
end
