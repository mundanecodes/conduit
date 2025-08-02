class UssdController < ApplicationController
  skip_before_action :verify_authenticity_token

  def handle
    # Process AfricasTalking USSD request
    response = Conduit.process(params)

    # Return plain text response for AfricasTalking
    render plain: response, content_type: "text/plain"
  end
end
