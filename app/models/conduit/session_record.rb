module Conduit
  class SessionRecord < ApplicationRecord
    self.table_name = "conduit_sessions"

    validates :session_id, presence: true, uniqueness: true
    validates :msisdn, presence: true
    validates :started_at, presence: true

    scope :completed, -> { where(completed: true) }
    scope :incomplete, -> { where(completed: false) }
    scope :recent, -> { order(created_at: :desc) }
    scope :for_phone, ->(msisdn) { where(msisdn:) }

    def self.from_session(session, completed: false)
      new(
        session_id: session.session_id,
        msisdn: session.msisdn,
        service_code: session.service_code,
        final_state: session.current_state,
        data: session.data,
        duration_seconds: session.duration.to_i,
        completed:,
        started_at: session.started_at,
        completed_at: completed ? Time.current : nil
      )
    end
  end
end
