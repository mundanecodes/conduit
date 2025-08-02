require "spec_helper"
require "mock_redis"

module Conduit
  RSpec.describe SessionStore do
    before do
      mock_redis = MockRedis.new
      allow(Redis).to receive(:new).and_return(mock_redis)
    end

    let(:store) { described_class.new }
    let(:session) do
      Session.new(
        session_id: "test123",
        msisdn: "254712345678",
        service_code: "*123#",
        current_state: "welcome",
        data: {name: "John"}
      )
    end

    describe "#set and #get" do
      it "stores and retrieves a session" do
        store.set(session)
        retrieved = store.get("test123")

        expect(retrieved.session_id).to eq("test123")
        expect(retrieved.msisdn).to eq("254712345678")
        expect(retrieved.current_state).to eq("welcome")
        expect(retrieved.data).to eq({"name" => "John"})
      end

      it "returns nil for non-existent session" do
        result = store.get("non-existent")
        expect(result).to be_nil
      end
    end

    describe "#delete" do
      it "removes a session" do
        store.set(session)
        store.delete("test123")

        result = store.get("test123")
        expect(result).to be_nil
      end
    end

    describe "error handling" do
      it "returns nil and logs on JSON parse errors" do
        # Set invalid JSON in Redis
        redis = Conduit.configuration.redis_pool.with { |r| r }
        redis.set("conduit:session:invalid", "invalid json")

        expect(Conduit.configuration.logger).to receive(:error).with(/Failed to get session/)

        result = store.get("invalid")
        expect(result).to be_nil
      end
    end
  end
end
