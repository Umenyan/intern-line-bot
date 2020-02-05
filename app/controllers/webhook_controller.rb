require 'line/bot'
require 'net/https'
require 'uri'
require 'json'

class WebhookController < ApplicationController
  protect_from_forgery except: [:callback] # CSRF対策無効化

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end

  def callback
    body = request.body.read

    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      head 470
    end

    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          text = event.message['text'].downcase
          messages = [
            generate_line_text_hash(text),
            generate_line_image_hash(text)
          ]
          client.reply_message(event['replyToken'], messages)
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    }
    head :ok
  end

  def generate_message(text)
    case text
    when "ねこ", "猫", "ネコ", "neko","cat"
      return "にゃんにゃん"
    when "いぬ", "犬", "イヌ", "inu", "dog"
      return "わんわん"
    else
      return "もふもふ"
    end
  end

  def generate_line_text_hash(text)
    return {
      type: 'text',
      text: generate_message(text)
    }
  end

  def call_bing_image_search_api(text)
    uri  = "https://api.cognitive.microsoft.com"
    path = "/bing/v7.0/images/search"
    
    uri = URI(uri + path + "?q=" + URI.escape(text))
    
    request = Net::HTTP::Get.new(uri)
    request['Ocp-Apim-Subscription-Key'] = ENV["BING_IMAGE_API_KEY"]

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(request)
    end

    return JSON.parse(response.body)
  end

  def generate_line_image_hash(text)
    parsed_json = call_bing_image_search_api(text)

    random_result = parsed_json["value"].sample
    
    originalContentUrl = random_result["contentUrl"]
    previewImageUrl = random_result["thumbnailUrl"]

    return {
      type: 'image',
      originalContentUrl: replace_to_https(originalContentUrl),
      previewImageUrl: replace_to_https(previewImageUrl) + "&c=4&w=240&h=240"
    }
  end

  def replace_to_https(url)
    return url.sub(/http:/, "https:")
  end
end
