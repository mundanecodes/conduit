module Conduit
  class Session
    attr_accessor :session_id, :msisdn, :service_code,
      :current_state, :navigation_stack, :data,
      :started_at, :last_activity_at

    def initialize(attrs = {})
      @session_id = attrs[:session_id]
      @msisdn = attrs[:msisdn]
      @service_code = attrs[:service_code]
      @current_state = attrs[:current_state] || "initial"
      @navigation_stack = attrs[:navigation_stack] || []
      @data = attrs[:data] || {}
      @started_at = attrs[:started_at] || Time.current
      @last_activity_at = attrs[:last_activity_at] || Time.current
    end

    def navigate_to(state)
      @navigation_stack.push(@current_state) unless @current_state == "initial"
      @navigation_stack = @navigation_stack.last(Conduit.configuration.max_navigation_depth)
      @current_state = state.to_s
      @last_activity_at = Time.current
    end

    def go_back
      previous_state = @navigation_stack.pop
      @current_state = previous_state if previous_state
      @last_activity_at = Time.current
    end

    def can_go_back?
      @navigation_stack.any?
    end

    def duration
      Time.current - @started_at
    end

    def expired?
      Time.current - @last_activity_at > Conduit.configuration.session_ttl
    end

    def to_h
      {
        session_id:,
        msisdn:,
        service_code:,
        current_state:,
        navigation_stack:,
        data:,
        started_at: started_at.to_i,
        last_activity_at: last_activity_at.to_i
      }
    end

    delegate :to_json, to: :to_h

    def self.from_hash(hash)
      hash = hash.with_indifferent_access

      new(
        session_id: hash[:session_id],
        msisdn: hash[:msisdn],
        service_code: hash[:service_code],
        current_state: hash[:current_state],
        navigation_stack: hash[:navigation_stack] || [],
        data: hash[:data] || {},
        started_at: Time.at((hash[:started_at] || Time.current).to_i),
        last_activity_at: Time.at((hash[:last_activity_at] || Time.current).to_i)
      )
    end
  end
end
