require "conduit/version"
require "conduit/engine"
require "conduit/configuration"
require "conduit/router"
require "conduit/middleware"
require "conduit/middleware/logging"
require "conduit/middleware/throttling"
require "conduit/middleware/session_tracking"
require "conduit/display_builder"
require "conduit/validator"

module Conduit
  class Error < StandardError; end

  class SessionTimeout < Error; end

  class InvalidTransition < Error; end

  mattr_accessor :configuration

  class << self
    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
    end

    def process(params)
      RequestHandler.new.process(params)
    end
  end
end
