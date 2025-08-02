require "rails/generators"
require "rails/generators/active_record"

module Conduit
  module Generators
    class MigrationGenerator < Rails::Generators::Base
      include ActiveRecord::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def create_migration_file
        migration_template "create_conduit_sessions.rb", "db/migrate/create_conduit_sessions.rb"
      end

      def display_post_install
        say "\n✅ Migration created!", :green
        say "\nRun 'rails db:migrate' to create the conduit_sessions table"
      end
    end
  end
end
