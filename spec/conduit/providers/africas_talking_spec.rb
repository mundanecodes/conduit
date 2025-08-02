require "spec_helper"

module Conduit
  module Providers
    RSpec.describe AfricasTalking do
      let(:params) do
        {
          sessionId: "AT_123",
          phoneNumber: "+254712345678",
          serviceCode: "*123#",
          networkCode: "62120",
          text: "1*2*3"
        }
      end

      let(:provider) { described_class.new(params) }

      describe "#parse_request" do
        it "extracts all parameters correctly" do
          result = provider.parse_request

          expect(result).to eq({
            session_id: "AT_123",
            msisdn: "254712345678",
            service_code: "*123#",
            network_code: "62120",
            raw_input: "1*2*3",
            input: "3"
          })
        end

        it "handles empty text" do
          params[:text] = ""
          result = provider.parse_request

          expect(result[:input]).to be_nil
          expect(result[:raw_input]).to eq("")
        end

        it "handles single input" do
          params[:text] = "1"
          result = provider.parse_request

          expect(result[:input]).to eq("1")
        end

        it "normalizes phone numbers" do
          params[:phoneNumber] = "+254-712-345-678"
          result = provider.parse_request

          expect(result[:msisdn]).to eq("254712345678")
        end
      end

      describe "#format_response" do
        it "formats continue response" do
          response = Response.new(text: "Enter amount:", action: :continue)
          formatted = provider.format_response(response)

          expect(formatted).to eq("CON Enter amount:")
        end

        it "formats end response" do
          response = Response.new(text: "Goodbye!", action: :end)
          formatted = provider.format_response(response)

          expect(formatted).to eq("END Goodbye!")
        end
      end
    end
  end
end
