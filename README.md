# Conduit

Lightning-fast USSD flow engine for Rails applications. Build interactive USSD services with an expressive DSL, Redis-backed session management, and built-in support for AfricasTalking.

## Features

- **Blazing Fast** - Redis-backed sessions with sub-50ms response times
- **Expressive DSL** - Write flows that read like specifications
- **AfricasTalking Ready** - Built-in provider support
- **Smart Navigation** - Automatic back (0) and home (00) handling
- **Production Ready** - Middleware, throttling, and error handling
- **Multi-language** - Easy internationalization support
- **60-120s Sessions** - Optimized for USSD's time constraints

## Installation

Add this line to your application's Gemfile:

```ruby
gem "conduit"

bundle install
rails generate conduit:install
```
