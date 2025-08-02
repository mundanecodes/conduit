module Conduit
  class Response
    attr_reader :text, :action

    def initialize(text:, action: :continue)
      @text = text
      @action = action.to_sym
    end

    def continue?
      @action == :continue
    end

    def end?
      @action == :end
    end
  end
end
