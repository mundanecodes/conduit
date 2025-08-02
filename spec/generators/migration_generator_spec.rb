require "spec_helper"
require "rails/generators"
require_relative "../../lib/generators/conduit/migration/migration_generator"

RSpec.describe Conduit::Generators::MigrationGenerator do
  include FileUtils

  let(:destination) { File.expand_path("../../tmp", __dir__) }

  before do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination, "db/migrate"))

    # Mock the migration timestamp
    allow(Time).to receive_message_chain(:now, :utc, :strftime).and_return("20240710120000")
  end

  after do
    rm_rf(destination)
  end

  def prepare_destination
    rm_rf(destination)
    mkdir_p(destination)
  end

  it "creates migration file" do
    run_generator

    migration_file = Dir[File.join(destination, "db/migrate/*_create_conduit_sessions.rb")].first
    expect(migration_file).not_to be_nil

    content = File.read(migration_file)
    expect(content).to include("create_table :conduit_sessions")
    expect(content).to include("t.string :session_id")
    expect(content).to include("t.jsonb :data")
  end

  private

  def run_generator(args = [])
    Conduit::Generators::MigrationGenerator.start(args, destination_root: destination)
  end
end
