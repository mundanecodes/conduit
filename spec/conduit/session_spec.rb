module Conduit
  RSpec.describe Session do
    let(:session) do
      described_class.new(
        session_id: "abc123",
        msisdn: "254712345678",
        service_code: "*123#"
      )
    end

    describe "#initialize" do
      it "sets default values" do
        expect(session.current_state).to eq("initial")
        expect(session.navigation_stack).to eq([])
        expect(session.data).to eq({})
        expect(session.started_at).to be_within(1.second).of(Time.current)
      end
    end

    describe "#navigate_to" do
      it "updates current state" do
        session.navigate_to(:menu)
        expect(session.current_state).to eq("menu")
      end

      it "pushes previous state to navigation stack" do
        session.current_state = "welcome"
        session.navigate_to(:menu)

        expect(session.navigation_stack).to eq(["welcome"])
      end
    end

    describe "#go_back" do
      it "returns to previous state" do
        session.navigate_to(:menu)
        session.navigate_to(:submenu)
        session.go_back

        expect(session.current_state).to eq("menu")
      end
    end
  end
end
