require "bundler/setup"
require "active_support"
require "active_support/core_ext"
require "json"
require "logger"
require "redis"
require "connection_pool"

module Rails
  def self.logger
    @logger ||= Logger.new($stdout).tap { it.level = Logger::WARN }
  end
end

require_relative "../lib/conduit/version"
require_relative "../lib/conduit/response"
require_relative "../lib/conduit/middleware"
require_relative "../lib/conduit/configuration"
require_relative "../lib/conduit/session"
require_relative "../lib/conduit/state"
require_relative "../lib/conduit/flow"
require_relative "../lib/conduit/session_store"
require_relative "../lib/conduit/router"
require_relative "../lib/conduit/providers/africas_talking"
require_relative "../lib/conduit/request_handler"

# Load middleware implementations
require_relative "../lib/conduit/middleware/logging"
require_relative "../lib/conduit/middleware/throttling"
require_relative "../lib/conduit/middleware/session_tracking"

module Conduit
  mattr_accessor :configuration

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end
end

# Initialize configuration
Conduit.configure {}

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random

  # Reset configs before each test
  config.before(:each) do
    Conduit.configuration = Conduit::Configuration.new
  end
end
