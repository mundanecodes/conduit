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

    describe "display helpers DSL" do
      it "supports display builder syntax" do
        test_flow = Class.new(Flow) do
          initial_state :menu

          state :menu do
            display do |session|
              header "Welcome #{session.data[:name]}", "Acme Corp"

              menu do
                option 1, "Profile"
                option 2, "Settings"
                exit_option
              end
            end

            on "1", to: :profile
            on "2", to: :settings
          end

          state :profile do
            display "Your Profile"
          end

          state :settings do
            display "Settings"
          end
        end

        session = Session.new(session_id: "test", msisdn: "254712345678", service_code: "*123#")
        session.data[:name] = "John"

        flow = test_flow.new
        response = flow.process(session, "")

        expected = <<~TEXT.strip
          Welcome John
          Acme Corp

          1. Profile
          2. Settings
          000. Exit
        TEXT

        expect(response.text).to eq(expected)
      end
    end

    describe "validation DSL" do
      it "validates input with built-in validators" do
        test_flow = Class.new(Flow) do
          initial_state :enter_amount

          state :enter_amount do
            display "Enter amount (1-1000):"

            validates :numeric
            validates :greater_than, 0
            validates :less_than, 1001

            on_valid do |input, session|
              session.data[:amount] = input.to_f
            end

            on_any to: :confirm
          end

          state :confirm do
            display do |session|
              "Confirm amount: #{session.data[:amount]}"
            end
          end
        end

        session = Session.new(session_id: "test", msisdn: "254712345678", service_code: "*123#")
        flow = test_flow.new

        # Valid input
        flow.process(session, "")
        flow.process(session, "500")
        expect(session.data[:amount]).to eq(500.0)
        expect(session.current_state).to eq("confirm")

        # Invalid - non-numeric
        session2 = Session.new(session_id: "test2", msisdn: "254712345678", service_code: "*123#")
        flow2 = test_flow.new
        flow2.process(session2, "")
        response = flow2.process(session2, "abc")
        expect(response.text).to include("valid number")
        expect(session2.current_state).to eq(:enter_amount)

        # Invalid - too large
        session3 = Session.new(session_id: "test3", msisdn: "254712345678", service_code: "*123#")
        flow3 = test_flow.new
        flow3.process(session3, "")
        response = flow3.process(session3, "2000")
        expect(response.text).to include("less than")
        expect(session3.current_state).to eq(:enter_amount)
      end

      it "supports custom validators" do
        test_flow = Class.new(Flow) do
          initial_state :enter_days

          state :enter_days do
            display "Enter number of days:"

            validates :numeric
            validates do |input, session|
              # Custom validation
              days = input.to_f
              if days <= 10
                true
              else
                "Cannot request more than 10 days at once"
              end
            end

            on_valid do |input, session|
              session.data[:days] = input.to_f
            end

            on_any to: :done
          end

          state :done do
            display "Done"
          end
        end

        session = Session.new(session_id: "test", msisdn: "254712345678", service_code: "*123#")
        flow = test_flow.new

        # Valid
        flow.process(session, "")
        flow.process(session, "5")
        expect(session.data[:days]).to eq(5.0)

        # Invalid - exceeds custom limit
        session2 = Session.new(session_id: "test2", msisdn: "254712345678", service_code: "*123#")
        flow2 = test_flow.new
        flow2.process(session2, "")
        response = flow2.process(session2, "15")
        expect(response.text).to include("Cannot request more than 10 days")
      end

      it "supports custom error handling with on_invalid" do
        test_flow = Class.new(Flow) do
          initial_state :enter_pin

          state :enter_pin do
            display "Enter 4-digit PIN:"

            validates :matches, /^\d{4}$/, "PIN must be exactly 4 digits"

            on_invalid do |error, session|
              session.data[:attempts] ||= 0
              session.data[:attempts] += 1

              if session.data[:attempts] >= 3
                Response.new(text: "Too many attempts. Goodbye.", action: :end)
              else
                Response.new(text: "#{error}\nAttempts: #{session.data[:attempts]}/3", action: :continue)
              end
            end

            on_valid do |input, session|
              session.data[:pin] = input
            end

            on_any to: :success
          end

          state :success do
            display "PIN accepted"
          end
        end

        session = Session.new(session_id: "test", msisdn: "254712345678", service_code: "*123#")
        flow = test_flow.new

        flow.process(session, "")

        # First invalid attempt
        response = flow.process(session, "12")
        expect(response.text).to include("PIN must be exactly 4 digits")
        expect(response.text).to include("Attempts: 1/3")
        expect(response).to be_continue

        # Second invalid attempt
        response = flow.process(session, "abc")
        expect(response.text).to include("Attempts: 2/3")

        # Third invalid attempt - should end
        response = flow.process(session, "12345")
        expect(response.text).to include("Too many attempts")
        expect(response).to be_end
      end
    end
  end
end
