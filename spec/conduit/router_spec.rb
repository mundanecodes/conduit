module Conduit
  class TestFlow < Flow
    initial_state :welcome
  end

  class AnotherFlow < Flow
    initial_state :menu
  end

  RSpec.describe Router do
    before do
      Router.instance_variable_set(:@routes, nil)
    end

    describe ".draw" do
      it "registers routes" do
        Router.draw do
          route "*123#", to: TestFlow
          route "*456#", to: AnotherFlow
        end

        expect(Router.routes).to eq({
          "123" => TestFlow,
          "456" => AnotherFlow
        })
      end

      it "normalizes service codes" do
        Router.draw do
          route "*789#", to: TestFlow
          route "444", to: AnotherFlow
        end

        expect(Router.routes).to eq({
          "789" => TestFlow,
          "444" => AnotherFlow
        })
      end
    end

    describe ".find_flow" do
      before do
        Router.draw do
          route "*123#", to: TestFlow
        end
      end

      it "returns flow instance for matching service code" do
        flow = Router.find_flow("*123#")
        expect(flow).to be_a(TestFlow)
      end

      it "normalizes service code when searching" do
        flow = Router.find_flow("123")
        expect(flow).to be_a(TestFlow)
      end

      it "raises error for unknown service code" do
        expect { Router.find_flow("*999#") }.to raise_error(/No flow found/)
      end
    end
  end
end
