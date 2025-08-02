module Conduit
  class Router
    class << self
      def routes
        @routes ||= {}
      end

      def draw(&)
        instance_eval(&)
      end

      def route(service_code, to:)
        routes[normalize_service_code(service_code)] = to
      end

      def find_flow(service_code)
        flow_class = routes[normalize_service_code(service_code)]
        raise "No flow found for service code: #{service_code}" unless flow_class

        flow_class.new
      end

      private

      def normalize_service_code(code)
        code.to_s.gsub(/\D/, "")
      end
    end
  end
end
