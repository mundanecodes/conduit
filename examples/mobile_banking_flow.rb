class MobileBankingFlow < Conduit::Flow
  initial_state :language_selection

  # Language selection
  state :language_selection do
    display <<~TEXT
      Welcome to FastBank
      Karibu FastBank

      1. English
      2. Kiswahili
    TEXT

    on "1" do |_, session|
      session.data[:language] = :en
      session.navigate_to(:authenticate)
    end

    on "2" do |_, session|
      session.data[:language] = :sw
      session.navigate_to(:authenticate)
    end
  end

  # PIN authentication
  state :authenticate do
    before_render do |session|
      session.data[:attempts] ||= 0
    end

    display do |session|
      if session.data[:language] == :sw
        "Tafadhali weka PIN yako:"
      else
        "Please enter your PIN:"
      end
    end

    on_any do |input, session|
      if valid_pin?(input, session.msisdn)
        session.data[:authenticated] = true
        session.data[:user_name] = fetch_user_name(session.msisdn)
        session.navigate_to(:main_menu)
      else
        session.data[:attempts] += 1

        if session.data[:attempts] >= 3
          msg = (session.data[:language] == :sw) ?
            "Umejaribu mara nyingi sana. Kwaheri!" :
            "Too many attempts. Goodbye!"
          Conduit::Response.new(text: msg, action: :end)
        else
          msg = (session.data[:language] == :sw) ?
            "PIN sio sahihi. Jaribu tena:" :
            "Invalid PIN. Try again:"
          Conduit::Response.new(text: msg)
        end
      end
    end
  end

  # Main menu
  state :main_menu do
    display do |session|
      if session.data[:language] == :sw
        <<~TEXT
          Karibu #{session.data[:user_name]}!

          1. Angalia salio
          2. Tuma pesa
          3. Lipa bili
          4. Mikopo
          5. Taarifa za akaunti
          6. Ondoka
        TEXT
      else
        <<~TEXT
          Welcome #{session.data[:user_name]}!

          1. Check balance
          2. Send money
          3. Pay bills
          4. Loans
          5. Mini statement
          6. Exit
        TEXT
      end
    end

    on "1", to: :check_balance
    on "2", to: :send_money
    on "3", to: :pay_bills
    on "4", to: :loans
    on "5", to: :mini_statement
    on "6" do |_, session|
      msg = (session.data[:language] == :sw) ?
        "Asante kwa kutumia Conduit Bank!" :
        "Thank you for using Conduit Bank!"
      Conduit::Response.new(text: msg, action: :end)
    end
  end

  # Balance inquiry
  state :check_balance do
    before_render do |session|
      session.data[:balance] = fetch_balance(session.msisdn)
    end

    display do |session|
      balance = format_money(session.data[:balance])

      if session.data[:language] == :sw
        <<~TEXT
          Salio lako ni KES #{balance}

          0. Rudi
          00. Menu kuu
        TEXT
      else
        <<~TEXT
          Your balance is KES #{balance}

          0. Back
          00. Main menu
        TEXT
      end
    end
  end

  # Send money flow
  state :send_money do
    display do |session|
      if session.data[:language] == :sw
        "Weka nambari ya simu ya mpokeaji:"
      else
        "Enter recipient phone number:"
      end
    end

    on_any do |input, session|
      if valid_phone_number?(input)
        session.data[:recipient] = input
        session.navigate_to(:send_amount)
      else
        msg = (session.data[:language] == :sw) ?
          "Nambari sio sahihi. Weka digiti 10:" :
          "Invalid number. Enter 10 digits:"
        Conduit::Response.new(text: msg)
      end
    end
  end

  state :send_amount do
    display do |session|
      if session.data[:language] == :sw
        "Weka kiasi cha kutuma:"
      else
        "Enter amount to send:"
      end
    end

    on_any do |input, session|
      amount = input.to_i
      balance = session.data[:balance] || fetch_balance(session.msisdn)

      if amount <= 0
        msg = (session.data[:language] == :sw) ?
          "Kiasi si sahihi. Jaribu tena:" :
          "Invalid amount. Try again:"
        Conduit::Response.new(text: msg)
      elsif amount > balance
        msg = (session.data[:language] == :sw) ?
          "Salio lako halitoshi. Weka kiasi kidogo:" :
          "Insufficient balance. Enter a lower amount:"
        Conduit::Response.new(text: msg)
      else
        session.data[:amount] = amount
        session.navigate_to(:confirm_send)
      end
    end
  end

  state :confirm_send do
    display do |session|
      amount = format_money(session.data[:amount])
      recipient = session.data[:recipient]
      fee = calculate_fee(session.data[:amount])
      total = format_money(session.data[:amount] + fee)

      if session.data[:language] == :sw
        <<~TEXT
          Tuma KES #{amount} kwa #{recipient}?
          Ada: KES #{fee}
          Jumla: KES #{total}

          1. Thibitisha
          2. Ghairi
        TEXT
      else
        <<~TEXT
          Send KES #{amount} to #{recipient}?
          Fee: KES #{fee}
          Total: KES #{total}

          1. Confirm
          2. Cancel
        TEXT
      end
    end

    on "1" do |_, session|
      result = process_transfer(
        from: session.msisdn,
        to: session.data[:recipient],
        amount: session.data[:amount]
      )

      msg = if result[:success]
        (session.data[:language] == :sw) ?
          "Umetuma KES #{format_money(session.data[:amount])} kwa #{session.data[:recipient]}. Kumbukumbu: #{result[:reference]}" :
          "You have sent KES #{format_money(session.data[:amount])} to #{session.data[:recipient]}. Reference: #{result[:reference]}"
      else
        (session.data[:language] == :sw) ?
          "Muamala umeshindwa. Tafadhali jaribu tena baadaye." :
          "Transaction failed. Please try again later."
      end

      Conduit::Response.new(text: msg, action: :end)
    end

    on "2", to: :main_menu
  end

  # Mini statement
  state :mini_statement do
    before_render do |session|
      session.data[:transactions] = fetch_recent_transactions(session.msisdn, limit: 5)
    end

    display do |session|
      transactions = session.data[:transactions]

      if session.data[:language] == :sw
        text = "Miamala ya hivi karibuni:\n\n"
        transactions.each do |tx|
          text += "#{tx[:date]} #{tx[:type]} KES #{format_money(tx[:amount])}\n"
        end
        text += "\n0. Rudi"
      else
        text = "Recent transactions:\n\n"
        transactions.each do |tx|
          text += "#{tx[:date]} #{tx[:type]} KES #{format_money(tx[:amount])}\n"
        end
        text += "\n0. Back"
      end

      text
    end
  end

  # Loan menu
  state :loans do
    display do |session|
      if session.data[:language] == :sw
        <<~TEXT
          Huduma za mkopo

          1. Omba mkopo
          2. Lipa mkopo
          3. Salio la mkopo
          0. Rudi
        TEXT
      else
        <<~TEXT
          Loan services

          1. Apply for loan
          2. Repay loan
          3. Loan balance
          0. Back
        TEXT
      end
    end

    on "1", to: :loan_application
    on "2", to: :loan_repayment
    on "3", to: :loan_balance
  end

  private

  def valid_pin?(pin, msisdn)
    # In production, this would check against secure storage
    pin == "1234"
  end

  def valid_phone_number?(number)
    number.match?(/^0\d{9}$/)
  end

  def fetch_user_name(msisdn)
    # In production, fetch from database
    "John Doe"
  end

  def fetch_balance(msisdn)
    # In production, fetch from core banking system
    5000
  end

  def format_money(amount)
    amount.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")
  end

  def calculate_fee(amount)
    case amount
    when 1..100 then 0
    when 101..500 then 11
    when 501..1000 then 15
    when 1001..1500 then 22
    when 1501..2500 then 28
    when 2501..3500 then 34
    when 3501..5000 then 39
    else 45
    end
  end

  def process_transfer(from:, to:, amount:)
    # In production, integrate with payment gateway
    {
      success: true,
      reference: "TXN#{SecureRandom.hex(4).upcase}"
    }
  end

  def fetch_recent_transactions(msisdn, limit: 5)
    # In production, fetch from database
    [
      {date: "10/01", type: "SEND", amount: -500},
      {date: "09/01", type: "RECV", amount: 1000},
      {date: "08/01", type: "BILL", amount: -250},
      {date: "07/01", type: "AIRTIME", amount: -100},
      {date: "06/01", type: "DEPOSIT", amount: 2000}
    ]
  end
end
