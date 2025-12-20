module Conduit
  class Response
    attr_reader :text, :action, :next_flow

    def initialize(text:, action: :continue, next_flow: nil)
      @text = text
      @action = action.to_sym
      @next_flow = next_flow
    end

    def continue?
      @action == :continue
    end

    def end?
      @action == :end
    end

    def transition?
      !@next_flow.nil?
    end
  end
end
