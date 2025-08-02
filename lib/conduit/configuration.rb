# lib/conduit/configuration.rb
module Conduit
  class Configuration
    attr_accessor :session_ttl, :redis_url, :max_navigation_depth,
      :redis_pool_size, :logger, :save_sessions

    def initialize
      @session_ttl = 90.seconds
      @redis_url = "redis://localhost:6379/1"
      @max_navigation_depth = 10
      @redis_pool_size = 10 # this number is experimental+configurable
      @logger = Rails.logger
      @save_sessions = true
      @middleware = ::Conduit::Middleware::Chain.new
    end

    attr_reader :middleware

    def redis_pool
      @redis_pool ||= ConnectionPool.new(size: redis_pool_size, timeout: 0.1) do
        Redis.new(url: redis_url, driver: :hiredis)
      end
    end
  end
end
