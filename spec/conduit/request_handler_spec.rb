require "spec_helper"
require "mock_redis"

module Conduit
  RSpec.describe RequestHandler do
    let(:handler) { described_class.new }
    let(:mock_redis) { MockRedis.new }

    before do
      allow(Redis).to receive(:new).and_return(mock_redis)
      Router.instance_variable_set(:@routes, nil) # Clear router state
    end

    describe "#process" do
      context "with valid flow" do
        before do
          # Create a fresh flow class
          test_flow = Class.new(Flow) do
            initial_state :welcome

            state :welcome do
              display "Welcome to Payments\n1. Send Money\n2. Exit"

              on "1", to: :enter_amount
              on "2" do
                Response.new(text: "Thank you!", action: :end)
              end
            end

            state :enter_amount do
              display "Enter amount:"

              on_any do |input, session|
                session.data[:amount] = input.to_i
                Response.new(text: "You entered #{input}. Transaction complete!", action: :end)
              end
            end
          end

          # Register the flow
          Router.draw do
            route "*789#", to: test_flow
          end
        end

        context "with new session" do
          let(:params) do
            {
              sessionId: "AT_NEW_001",
              phoneNumber: "+254712345678",
              serviceCode: "*789#",
              text: ""
            }
          end

          it "creates session and returns welcome message" do
            response = handler.process(params)

            expect(response).to eq("CON Welcome to Payments\n1. Send Money\n2. Exit")
          end

          it "stores session in Redis" do
            handler.process(params)

            store = SessionStore.new
            session = store.get("AT_NEW_001")

            expect(session).not_to be_nil
            expect(session.msisdn).to eq("254712345678")
            expect(session.current_state).to eq("welcome")
          end
        end

        context "with existing session" do
          it "continues conversation" do
            # Unique session ID
            session_id = "AT_CONTINUE_#{Time.now.to_i}"

            # First request
            params1 = {
              sessionId: session_id,
              phoneNumber: "+254712345678",
              serviceCode: "*789#",
              text: ""
            }
            response1 = handler.process(params1)
            expect(response1).to eq("CON Welcome to Payments\n1. Send Money\n2. Exit")

            # Second request - user presses 1
            params2 = params1.merge(text: "1")
            response2 = handler.process(params2)
            expect(response2).to eq("CON Enter amount:")
          end

          it "handles session ending" do
            # Unique session ID for this test
            session_id = "AT_END_#{Time.now.to_i}"

            # Welcome screen
            params1 = {
              sessionId: session_id,
              phoneNumber: "+254712345678",
              serviceCode: "*789#",
              text: ""
            }
            response1 = handler.process(params1)
            expect(response1).to eq("CON Welcome to Payments\n1. Send Money\n2. Exit")

            # User presses 2 to exit
            params2 = params1.merge(text: "2")
            response2 = handler.process(params2)
            expect(response2).to eq("END Thank you!")

            # Verify session was deleted
            store = SessionStore.new
            session = store.get(session_id)
            expect(session).to be_nil
          end

          it "completes full flow" do
            session_id = "AT_FULL_#{Time.now.to_i}"
            base_params = {
              sessionId: session_id,
              phoneNumber: "+254712345678",
              serviceCode: "*789#"
            }

            # Welcome
            handler.process(base_params.merge(text: ""))

            # Send Money
            handler.process(base_params.merge(text: "1"))

            # Enter amount
            response = handler.process(base_params.merge(text: "1*500"))
            expect(response).to eq("END You entered 500. Transaction complete!")
          end
        end

        context "with expired session" do
          it "returns expiry message" do
            session_id = "AT_EXPIRED_#{Time.now.to_i}"

            # Create expired session
            expired_session = Session.new(
              session_id:,
              msisdn: "254712345678",
              service_code: "*789#",
              last_activity_at: 2.minutes.ago
            )

            store = SessionStore.new
            store.set(expired_session)

            params = {
              sessionId: session_id,
              phoneNumber: "+254712345678",
              serviceCode: "*789#",
              text: "1"
            }

            response = handler.process(params)
            expect(response).to eq("END Your session has expired. Please dial again.")
          end
        end

        context "edge cases" do
          it "handles missing phone number gracefully" do
            params = {
              sessionId: "AT_MISSING_#{Time.now.to_i}",
              phoneNumber: nil,
              serviceCode: "*789#",
              text: ""
            }

            response = handler.process(params)
            expect(response).to eq("CON Welcome to Payments\n1. Send Money\n2. Exit")
          end
        end
      end

      context "error handling" do
        before do
          allow(Conduit.configuration.logger).to receive(:error)
        end

        it "handles unknown service codes gracefully" do
          params = {
            sessionId: "AT_ERROR_#{Time.now.to_i}",
            phoneNumber: "+254712345678",
            serviceCode: "*999#",  # This serviceCoce Not registered, it should not raise
            text: ""
          }

          response = handler.process(params)
          expect(response).to eq("END Service temporarily unavailable")

          expect(Conduit.configuration.logger).to have_received(:error).with(/No flow found/)
        end
      end

      context "with flow transitions" do
        before do
          # Create an authentication flow that transitions to main menu
          auth_flow = Class.new(Flow) do
            initial_state :enter_pin

            state :enter_pin do
              display "Enter your PIN:"

              on_any do |input, session|
                if input == "1234"
                  session.data[:authenticated] = true
                  # Return a flow transition to MainMenu
                  Response.new(
                    text: "Welcome!",
                    action: :continue,
                    next_flow: Object.const_get("Conduit::MainMenuFlow")
                  )
                else
                  Response.new(text: "Invalid PIN. Try again:")
                end
              end
            end
          end

          # Create a main menu flow
          main_menu_flow = Class.new(Flow) do
            initial_state :menu

            state :menu do
              display "Main Menu\n1. Profile\n2. Logout"

              on "1" do
                Response.new(text: "Profile: John Doe", action: :end)
              end

              on "2" do
                Response.new(text: "Goodbye!", action: :end)
              end
            end
          end

          # Make flows available as constants
          stub_const("Conduit::AuthFlow", auth_flow)
          stub_const("Conduit::MainMenuFlow", main_menu_flow)

          # Register the authentication flow
          Router.draw do
            route "*384#", to: auth_flow
          end
        end

        it "transitions from one flow to another automatically" do
          session_id = "AT_TRANSITION_#{Time.now.to_i}"

          # Step 1: Enter PIN
          params1 = {
            sessionId: session_id,
            phoneNumber: "+254712345678",
            serviceCode: "*384#",
            text: ""
          }
          response1 = handler.process(params1)
          expect(response1).to eq("CON Enter your PIN:")

          # Step 2: Correct PIN - should show welcome and set pending transition
          params2 = params1.merge(text: "1234")
          response2 = handler.process(params2)
          expect(response2).to eq("CON Welcome!")

          # Verify pending_flow_transition was set in session
          store = SessionStore.new
          session = store.get(session_id)
          expect(session.data[:pending_flow_transition]).to eq("Conduit::MainMenuFlow")

          # Step 3: Next input should process in MainMenuFlow
          params3 = params1.merge(text: "1234*1")
          response3 = handler.process(params3)
          expect(response3).to eq("CON Main Menu\n1. Profile\n2. Logout")

          # Verify pending_flow_transition was cleared
          session = store.get(session_id)
          expect(session.data[:pending_flow_transition]).to be_nil
        end

        it "processes empty input in transitioned flow to show initial state" do
          session_id = "AT_TRANSITION_EMPTY_#{Time.now.to_i}"

          # Step 1: Enter PIN
          params1 = {
            sessionId: session_id,
            phoneNumber: "+254712345678",
            serviceCode: "*384#",
            text: ""
          }
          handler.process(params1)

          # Step 2: Correct PIN
          params2 = params1.merge(text: "1234")
          handler.process(params2)

          # Step 3: Simulate user pressing any key to continue
          # The transitioned flow should be called with empty input to display initial state
          params3 = params1.merge(text: "1234*")
          response3 = handler.process(params3)
          expect(response3).to eq("CON Main Menu\n1. Profile\n2. Logout")
        end

        it "allows user interaction in transitioned flow" do
          session_id = "AT_TRANSITION_INTERACT_#{Time.now.to_i}"

          # Go through authentication
          params = {
            sessionId: session_id,
            phoneNumber: "+254712345678",
            serviceCode: "*384#",
            text: ""
          }
          handler.process(params)
          handler.process(params.merge(text: "1234"))

          # Now in MainMenuFlow, select Profile
          response = handler.process(params.merge(text: "1234*1"))
          expect(response).to eq("CON Main Menu\n1. Profile\n2. Logout")

          # Select option 1 (Profile)
          response = handler.process(params.merge(text: "1234*1*1"))
          expect(response).to eq("END Profile: John Doe")
        end
      end
    end
  end
end
