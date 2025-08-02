class TestBankingFlow < Conduit::Flow
  initial_state :welcome

  state :welcome do
    display "Welcome to TestBank\n1. Check Balance\n2. Exit"

    on "1", to: :check_balance
    on "2" do |_, _|
      Conduit::Response.new(text: "Thank you for banking with us!", action: :end)
    end
  end

  state :check_balance do
    display do |session|
      "Your balance is KES #{session.data[:balance] || 1000}\n\n0. Back"
    end
  end
end

module Conduit
  RSpec.describe Flow do
    let(:flow) { TestBankingFlow.new }
    let(:session) { Session.new(session_id: "test123", msisdn: "254712345678") }

    describe "DSL" do
      it "sets initial state" do
        expect(TestBankingFlow.initial_state_name).to eq(:welcome)
      end

      it "defines states" do
        expect(TestBankingFlow.states.keys).to include(:welcome, :check_balance)
      end
    end

    describe "#process" do
      it "renders initial state" do
        response = flow.process(session)

        expect(response.text).to include("Welcome to TestBank")
        expect(response.action).to eq(:continue)
        expect(session.current_state.to_s).to eq("welcome")  # Changed to string
      end

      it "handles navigation" do
        flow.process(session) # Initialize
        response = flow.process(session, "1")

        expect(session.current_state).to eq("check_balance")  # Changed to string
        expect(response.text).to include("Your balance is KES 1000")
      end

      it "handles end action" do
        flow.process(session) # Initialize
        response = flow.process(session, "2")

        expect(response.action).to eq(:end)
        expect(response.text).to eq("Thank you for banking with us!")
      end

      it "handles back navigation with 0" do
        flow.process(session) # Welcome
        flow.process(session, "1") # Go to balance
        response = flow.process(session, "0") # Go back

        expect(session.current_state.to_s).to eq("welcome")  # Changed to string
        expect(response.text).to include("Welcome to TestBank")
      end
    end
  end
end
