class ExampleFlow < Conduit::Flow
  initial_state :welcome

  state :welcome do
    display <<~TEXT
      Welcome to Conduit USSD Demo!

      1. Get Started
      2. About
      3. Exit
    TEXT

    on "1", to: :get_name
    on "2", to: :about
    on "3" do
      Conduit::Response.new(text: "Thank you for using Conduit! Goodbye.", action: :end)
    end
  end

  state :get_name do
    display "What's your name?"

    on_any do |input, session|
      session.data[:name] = input
      session.navigate_to(:greet)
    end
  end

  state :greet do
    display do |session|
      <<~TEXT
        Hello #{session.data[:name]}!

        You have successfully set up Conduit.

        1. Try something else
        0. Back
        00. Home
      TEXT
    end

    on "1", to: :demo_feature
  end

  state :about do
    display <<~TEXT
      Conduit v#{Conduit::VERSION}

      Lightning-fast USSD framework for Rails
      Built with ❤️ for Africa

      0. Back
      00. Home
    TEXT
  end

  state :demo_feature do
    display do |session|
      <<~TEXT
        #{session.data[:name]}, this is where you'd add your features!

        Current session info:
        - ID: #{session.session_id}
        - Phone: #{session.msisdn}
        - Duration: #{session.duration.to_i}s

        0. Back
        00. Home
      TEXT
    end
  end
end
