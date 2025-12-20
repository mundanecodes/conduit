# Conduit

Lightning-fast USSD flow engine for Rails applications. Build interactive USSD services with an expressive DSL, Redis-backed session management, and built-in support for AfricasTalking.

## Design Philosophy

Conduit is built on four core principles that make USSD development in Africa a joy:

### 1. **Speed is Everything**
USSD sessions have a strict 60-120 second timeout. Every millisecond counts. Conduit uses Redis connection pooling, minimal middleware overhead, and optimized session serialization to deliver sub-50ms response times.

### 2. **Developer Experience First**
Your flow code should read like a specification. Conduit's DSL is designed to be self-documenting, making it easy for teams to understand, maintain, and extend USSD applications.

```ruby
state :welcome do
  display "Welcome! What would you like to do?"
  on "1", to: :check_balance
  on "2", to: :send_money
end
```

### 3. **African Mobile Networks are Unique**
Built specifically for African telecom infrastructure. Handles network delays, session drops, and the quirks of different USSD gateways. First-class support for AfricasTalking with extensible provider architecture.

### 4. **Production-Grade from Day One**
Includes middleware for logging, throttling, and session tracking. Built-in error handling, session persistence, and monitoring hooks. Deploy with confidence.

## Features

- **Blazing Fast** - Redis-backed sessions with sub-50ms response times
- **Expressive DSL** - Write flows that read like specifications  
- **AfricasTalking Ready** - Built-in provider support with extensible architecture
- **Smart Navigation** - Automatic back (0) and home (00) handling with navigation stack
- **Production Ready** - Middleware, throttling, error handling, and session persistence
- **Multi-language** - Easy internationalization support
- **60-120s Sessions** - Optimized for USSD's time constraints
- **Rails Integration** - Seamless Rails engine with generators and conventions

## Quick Start

### Installation

Add to your Gemfile:

```ruby
gem "conduit"
```

Then run:

```bash
bundle install
rails generate conduit:install
rails generate conduit:migration
rails db:migrate
```

### Your First Flow

```ruby
# app/flows/banking_flow.rb
class BankingFlow < Conduit::Flow
  initial_state :welcome

  state :welcome do
    display <<~TEXT
      Welcome to MobileBank
      
      1. Check Balance
      2. Send Money
      3. Buy Airtime
    TEXT

    on "1", to: :check_balance
    on "2", to: :send_money
    on "3", to: :buy_airtime
  end

  state :check_balance do
    display do |session|
      balance = User.find_by(phone: session.msisdn)&.balance || 0
      "Your balance is KES #{balance}"
    end
  end

  state :send_money do
    display "Enter phone number:"
    
    on_any do |input, session|
      if valid_phone?(input)
        session.data[:recipient] = input
        session.navigate_to(:enter_amount)
      else
        Conduit::Response.new(text: "Invalid phone number. Try again:")
      end
    end
  end

  state :enter_amount do
    display do |session|
      "Send money to #{session.data[:recipient]}\nEnter amount:"
    end

    on_any do |input, session|
      amount = input.to_i
      if amount > 0 && amount <= user_balance(session)
        process_transfer(session, amount)
        Conduit::Response.new(text: "Money sent successfully!", action: :end)
      else
        Conduit::Response.new(text: "Invalid amount. Try again:")
      end
    end
  end

  private

  def valid_phone?(phone)
    phone.match?(/^254\d{9}$/)
  end

  def user_balance(session)
    User.find_by(phone: session.msisdn)&.balance || 0
  end

  def process_transfer(session, amount)
    # Your transfer logic here
    TransferService.new(
      from: session.msisdn,
      to: session.data[:recipient],
      amount: amount
    ).call
  end
end
```

### Configuration

```ruby
# config/initializers/conduit.rb
Conduit.configure do |config|
  config.redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
  config.session_ttl = 90.seconds
  config.max_navigation_depth = 10

  # Middleware (order matters)
  config.middleware.use Conduit::Middleware::Logging
  config.middleware.use Conduit::Middleware::Throttling, max_requests: 20, window: 60
  config.middleware.use Conduit::Middleware::SessionTracking
end

# Route service codes to flows
Conduit::Router.draw do
  route "*123#", to: BankingFlow
  route "*456#", to: AirtimeFlow
  route "*789#", to: UtilitiesFlow
end
```

### Controller

```ruby
# app/controllers/ussd_controller.rb
class UssdController < ApplicationController
  def handle
    handler = Conduit::RequestHandler.new(
      Conduit::Providers::AfricasTalking.new(params)
    )
    
    response = handler.process
    render plain: response
  end
end
```

## Advanced Features

### Session Management

```ruby
state :collect_info do
  display "Enter your name:"
  
  on_any do |input, session|
    session.data[:user_name] = input
    session.data[:collected_at] = Time.current
    session.navigate_to(:confirm)
  end
end

state :confirm do
  display do |session|
    "Hello #{session.data[:user_name]}!
    Session started: #{session.started_at}
    Duration: #{session.duration.to_i}s"
  end
end
```

### Navigation Stack

```ruby
# Automatic back/home handling
state :menu do
  display <<~TEXT
    Main Menu
    1. Services
    2. Account
    
    0. Back
    00. Home
  TEXT
  
  # 0 and 00 are handled automatically
  on "1", to: :services
  on "2", to: :account
end
```

### Conditional Flows

```ruby
state :check_eligibility do
  display "Checking your eligibility..."
  
  transition do |session|
    user = User.find_by(phone: session.msisdn)
    
    if user&.kyc_verified?
      :premium_services
    elsif user&.basic_verified?
      :basic_services  
    else
      :verification_required
    end
  end
end
```

### Error Handling

```ruby
state :risky_operation do
  display "Processing..."
  
  on_any do |input, session|
    begin
      result = ExternalService.call(input)
      session.navigate_to(:success)
    rescue ExternalService::Error => e
      Conduit.logger.error("Service failed: #{e.message}")
      Conduit::Response.new(text: "Service temporarily unavailable. Try again later.", action: :end)
    end
  end
end
```

### Custom Middleware

```ruby
class AuthenticationMiddleware < Conduit::Middleware::Base
  def call(env)
    session = env[:session]
    
    unless authenticated?(session.msisdn)
      return Conduit::Response.end("Please register first by dialing *100#")
    end
    
    @app.call(env)
  end
  
  private
  
  def authenticated?(phone)
    User.exists?(phone: phone, status: 'active')
  end
end

# Add to config
config.middleware.use AuthenticationMiddleware
```

## Testing

```ruby
# spec/flows/banking_flow_spec.rb
RSpec.describe BankingFlow do
  let(:session) { build_session(msisdn: "254712345678") }
  let(:flow) { described_class.new }

  describe "welcome state" do
    it "displays menu options" do
      response = flow.process(session)
      
      expect(response.text).to include("Welcome to MobileBank")
      expect(response.text).to include("1. Check Balance")
      expect(response).to be_continue
    end
  end

  describe "balance inquiry" do
    before { session.current_state = :welcome }
    
    it "shows balance when option 1 is selected" do
      create(:user, phone: "254712345678", balance: 1500)
      
      response = flow.process(session, "1")
      
      expect(response.text).to include("Your balance is KES 1500")
      expect(response).to be_end
    end
  end
end
```

## Deployment

### Production Configuration

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_URL'],
  pool_size: 20,
  pool_timeout: 0.1
}

# Use separate Redis instance for Conduit sessions
Conduit.configure do |config|
  config.redis_url = ENV.fetch("CONDUIT_REDIS_URL", ENV["REDIS_URL"])
  config.redis_pool_size = 20
  config.session_ttl = 120.seconds
end
```

### Monitoring

```ruby
# config/initializers/conduit.rb
class MetricsMiddleware < Conduit::Middleware::Base
  def call(env)
    start_time = Time.current
    
    result = @app.call(env)
    
    duration = (Time.current - start_time) * 1000
    Rails.logger.info("USSD Response time: #{duration.round(2)}ms")
    
    # Send to your monitoring service
    StatsD.histogram('ussd.response_time', duration)
    
    result
  end
end

config.middleware.use MetricsMiddleware
```

## Provider Support

Currently supports AfricasTalking with extensible provider architecture:

```ruby
# Custom provider
class CustomProvider
  def initialize(params)
    @params = params
  end
  
  def parse_request
    {
      session_id: @params[:session_id],
      msisdn: @params[:phone_number],
      service_code: @params[:service_code], 
      input: @params[:user_input]
    }
  end
  
  def format_response(response)
    {
      message: response.text,
      action: response.end? ? 'terminate' : 'continue'
    }.to_json
  end
end
```

## Architecture

Conduit follows a middleware-based architecture:

```
Request → Provider → Middleware Chain → Router → Flow → Response → Provider → Response
```

- **Provider**: Parses telecom-specific requests
- **Middleware**: Cross-cutting concerns (logging, throttling, auth)
- **Router**: Maps service codes to flows
- **Flow**: Your business logic
- **Session**: Redis-backed state management

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rspec`)
5. Run the linter (`bundle exec rubocop`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Support

- 📧 Email: support@conduit-ussd.com
- 🐛 Issues: [GitHub Issues](https://github.com/chalchuck/conduit/issues)
- 📖 Docs: [Full Documentation](https://docs.conduit-ussd.com)
- 💬 Community: [Discord](https://discord.gg/conduit-ussd)

---

Built with ❤️ for African developers by African developers.