module Conduit
  class SessionStore
    def initialize
      @pool = Conduit.configuration.redis_pool
    end

    def get(session_id)
      @pool.with do |redis|
        data = redis.get(key_for(session_id))
        return nil unless data

        Session.from_hash(JSON.parse(data))
      end
    rescue => e
      Conduit.configuration.logger.error "Failed to get session #{session_id}: #{e.message}"
      nil
    end

    def set(session)
      @pool.with do |redis|
        redis.setex(
          key_for(session.session_id),
          Conduit.configuration.session_ttl.to_i,
          session.to_json
        )
      end
    end

    def delete(session_id)
      @pool.with do |redis|
        redis.del(key_for(session_id))
      end
    end

    private

    def key_for(session_id)
      "conduit:session:#{session_id}"
    end
  end
end
