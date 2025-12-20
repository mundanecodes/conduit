require "spec_helper"

module Conduit
  RSpec.describe DisplayBuilder do
    describe "#header" do
      it "adds header text with blank line after" do
        builder = DisplayBuilder.new
        builder.header("Welcome to USSD")

        expect(builder.to_s).to eq("Welcome to USSD\n")
      end

      it "supports multiple header lines" do
        builder = DisplayBuilder.new
        builder.header("Welcome", "Acme Corp")

        expect(builder.to_s).to eq("Welcome\nAcme Corp\n")
      end
    end

    describe "#text" do
      it "adds plain text" do
        builder = DisplayBuilder.new
        builder.text("Some content")

        expect(builder.to_s).to eq("Some content")
      end
    end

    describe "#menu" do
      it "builds a menu with options" do
        builder = DisplayBuilder.new
        builder.menu do
          option 1, "Send Money"
          option 2, "Check Balance"
        end

        expect(builder.to_s).to eq("1. Send Money\n2. Check Balance")
      end

      it "supports back option" do
        builder = DisplayBuilder.new
        builder.menu do
          option 1, "Profile"
          back_option
        end

        expect(builder.to_s).to eq("1. Profile\n0. Back")
      end

      it "supports home option" do
        builder = DisplayBuilder.new
        builder.menu do
          option 1, "Settings"
          home_option
        end

        expect(builder.to_s).to eq("1. Settings\n00. Main Menu")
      end

      it "supports exit option" do
        builder = DisplayBuilder.new
        builder.menu do
          option 1, "Logout"
          exit_option
        end

        expect(builder.to_s).to eq("1. Logout\n000. Exit")
      end

      it "supports custom text for navigation options" do
        builder = DisplayBuilder.new
        builder.menu do
          option 1, "Continue"
          back_option "Previous"
          exit_option "Cancel"
        end

        expect(builder.to_s).to eq("1. Continue\n0. Previous\n000. Cancel")
      end
    end

    describe "#blank_line" do
      it "adds a blank line" do
        builder = DisplayBuilder.new
        builder.text("Line 1")
        builder.blank_line
        builder.text("Line 2")

        expect(builder.to_s).to eq("Line 1\n\nLine 2")
      end
    end

    describe "complete example" do
      it "builds a complete USSD screen" do
        builder = DisplayBuilder.new
        builder.header("Welcome John", "Acme Corp")
        builder.text("Select an option:")
        builder.blank_line
        builder.menu do
          option 1, "Leave Management"
          option 2, "My Info"
          exit_option
        end

        expected = <<~TEXT.strip
          Welcome John
          Acme Corp

          Select an option:

          1. Leave Management
          2. My Info
          000. Exit
        TEXT

        expect(builder.to_s).to eq(expected)
      end
    end
  end
end
