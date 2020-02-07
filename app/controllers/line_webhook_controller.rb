require 'line/bot'
require 'net/https'
require 'uri'
require 'json'

class LineWebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']

    line_service = LineService.new
    
    if line_service.validate_signature(body, signature)
      line_service.call(body)

      head :ok
    else
      head 470
    end
  end
end
