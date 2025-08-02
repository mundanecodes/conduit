module Conduit
  module Providers
    class AfricasTalking
      attr_reader :params

      def initialize(params)
        @params = params
      end

      def parse_request
        {
          session_id: params[:sessionId],
          msisdn: normalize_phone_number(params[:phoneNumber]),
          service_code: params[:serviceCode],
          network_code: params[:networkCode],
          raw_input: params[:text],
          input: extract_latest_input(params[:text])
        }
      end

      def format_response(response)
        prefix = response.end? ? "END " : "CON "
        "#{prefix}#{response.text}"
      end

      private

      def extract_latest_input(text)
        return nil if text.blank?
        text.split("*").last
      end

      # for this one we can use Phobelib.parse(phone).to_s :thinkng?
      def normalize_phone_number(phone)
        phone.to_s.gsub(/\D/, "")
      end
    end
  end
end
