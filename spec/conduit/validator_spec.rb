require "spec_helper"

module Conduit
  RSpec.describe Validator do
    let(:session) { Session.new(session_id: "test", msisdn: "254712345678", service_code: "*123#") }

    describe ".numeric" do
      it "validates numeric input" do
        validator = Validator.numeric
        expect(validator.call("123", session)).to be true
        expect(validator.call("12.5", session)).to be true
      end

      it "rejects non-numeric input" do
        validator = Validator.numeric
        result = validator.call("abc", session)
        expect(result).to be_a(String)
        expect(result).to include("valid number")
      end
    end

    describe ".greater_than" do
      it "validates input greater than threshold" do
        validator = Validator.greater_than(10)
        expect(validator.call("15", session)).to be true
        expect(validator.call("10.1", session)).to be true
      end

      it "rejects input less than or equal to threshold" do
        validator = Validator.greater_than(10)
        result = validator.call("5", session)
        expect(result).to be_a(String)
        expect(result).to include("greater than 10")
      end
    end

    describe ".less_than" do
      it "validates input less than threshold" do
        validator = Validator.less_than(100)
        expect(validator.call("50", session)).to be true
      end

      it "rejects input greater than or equal to threshold" do
        validator = Validator.less_than(100)
        result = validator.call("150", session)
        expect(result).to be_a(String)
        expect(result).to include("less than 100")
      end
    end

    describe ".min_length" do
      it "validates input with minimum length" do
        validator = Validator.min_length(5)
        expect(validator.call("hello", session)).to be true
        expect(validator.call("hello world", session)).to be true
      end

      it "rejects input shorter than minimum" do
        validator = Validator.min_length(5)
        result = validator.call("hi", session)
        expect(result).to be_a(String)
        expect(result).to include("at least 5 characters")
      end
    end

    describe ".max_length" do
      it "validates input within maximum length" do
        validator = Validator.max_length(10)
        expect(validator.call("hello", session)).to be true
      end

      it "rejects input longer than maximum" do
        validator = Validator.max_length(10)
        result = validator.call("this is too long", session)
        expect(result).to be_a(String)
        expect(result).to include("at most 10 characters")
      end
    end

    describe ".matches" do
      it "validates input matching pattern" do
        validator = Validator.matches(/^\d{4}$/, "Must be 4 digits")
        expect(validator.call("1234", session)).to be true
      end

      it "rejects input not matching pattern" do
        validator = Validator.matches(/^\d{4}$/, "Must be 4 digits")
        result = validator.call("abc", session)
        expect(result).to eq("Must be 4 digits")
      end
    end

    describe ".in_range" do
      it "validates input within range" do
        validator = Validator.in_range(1, 10)
        expect(validator.call("5", session)).to be true
        expect(validator.call("1", session)).to be true
        expect(validator.call("10", session)).to be true
      end

      it "rejects input outside range" do
        validator = Validator.in_range(1, 10)
        result = validator.call("15", session)
        expect(result).to be_a(String)
        expect(result).to include("between 1 and 10")
      end
    end
  end
end
