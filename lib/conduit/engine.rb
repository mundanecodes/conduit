require "redis"
require "connection_pool"

module Conduit
  class Engine < ::Rails::Engine
    isolate_namespace Conduit

    config.generators do |generator|
      generator.test_framework :rspec
    end

    config.autoload_paths << File.expand_path("../", __dir__)

    initializer "conduit.setup" do
      Conduit.configure do |config|
        config.session_ttl ||= 90.seconds
        config.redis_url ||= ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
      end
    end
  end
end
