require "rails/generators"

module Conduit
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def create_initializer
        template "conduit.rb", "config/initializers/conduit.rb"
      end

      def create_controller
        template "ussd_controller.rb", "app/controllers/ussd_controller.rb"
      end

      def add_routes
        route 'post "/ussd", to: "ussd#handle"'
      end

      def create_flow_directory
        empty_directory "app/flows"
        template "example_flow.rb", "app/flows/example_flow.rb"
      end

      def display_post_install
        say "\n✅ Conduit installed successfully!", :green
        say "\nNext steps:"
        say "  1. Configure Redis in config/initializers/conduit.rb"
        say "  2. Run 'rails generate conduit:migration' to create database table"
        say "  3. Run 'rails db:migrate'"
        say "  4. Create your flows in app/flows/"
        say "  5. Map service codes to flows in the initializer"
        say "  6. Test your USSD endpoint: POST /ussd"
        say "\nExample AfricasTalking request:"
        say "  curl -X POST http://localhost:3000/ussd \\"
        say '    -H "Content-Type: application/x-www-form-urlencoded" \\'
        say '    -d "sessionId=test123&phoneNumber=254712345678&serviceCode=*123%23&text="'
      end
    end
  end
end
