require "spec_helper"
require "rails/generators"
require_relative "../../lib/generators/conduit/install/install_generator"

RSpec.describe Conduit::Generators::InstallGenerator do
  include FileUtils

  let(:destination) { File.expand_path("../../tmp", __dir__) }

  before do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination, "config"))
    FileUtils.mkdir_p(File.join(destination, "app/controllers"))

    File.write(File.join(destination, "config/routes.rb"), "Rails.application.routes.draw do\nend")
  end

  after do
    rm_rf(destination)
  end

  def prepare_destination
    rm_rf(destination)
    mkdir_p(destination)
  end

  it "creates initializer file" do
    run_generator

    expect(File.exist?(File.join(destination, "config/initializers/conduit.rb"))).to be true
  end

  it "creates controller file" do
    run_generator

    expect(File.exist?(File.join(destination, "app/controllers/ussd_controller.rb"))).to be true
  end

  it "creates example flow" do
    run_generator

    expect(File.exist?(File.join(destination, "app/flows/example_flow.rb"))).to be true
  end

  it "adds route" do
    run_generator

    routes = File.read(File.join(destination, "config/routes.rb"))
    expect(routes).to include('post "/ussd", to: "ussd#handle"')
  end

  private

  def run_generator(args = [])
    Conduit::Generators::InstallGenerator.start(args, destination_root: destination)
  end
end
