Conduit.configure do |config|
  # Redis configuration
  config.redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
  config.session_ttl = 90.seconds

  # Logging
  config.logger = Rails.logger

  # Session settings
  config.max_navigation_depth = 10
  config.save_sessions = true

  # Middleware (order matters - first added is outermost)
  config.middleware.use Conduit::Middleware::Logging
  config.middleware.use Conduit::Middleware::Throttling, max_requests: 20, window: 60
  config.middleware.use Conduit::Middleware::SessionTracking

  # Add custom middleware
  # config.middleware.use MyCustomMiddleware
end

# Route service codes to flows
Conduit::Router.draw do
  route "*123#", to: ExampleFlow
  # route "*456#", to: AnotherFlow
end
