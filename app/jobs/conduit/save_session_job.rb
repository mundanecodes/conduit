module Conduit
  class SaveSessionJob < ApplicationJob
    queue_as :default

    def perform(session_data)
      session = Session.from_hash(session_data)
      record = SessionRecord.from_session(session, completed: true)
      record.save!
    end
  end
end
