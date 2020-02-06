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
          input_text = event.message['text'].downcase
          responce = client.reply_message(event['replyToken'], generate_line_massage_array(input_text))
          p responce.message
          p JSON.parse(responce.body)
        when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
          response = client.get_message_content(event.message['id'])
          tf = Tempfile.open("content")
          tf.write(response.body)
        end
      end
    }
    head :ok
  end

  def generate_message(input_text)
    case input_text
    when "ねこ", "猫", "ネコ", "neko","cat"
      return "にゃんにゃん"
    when "いぬ", "犬", "イヌ", "inu", "dog"
      return "わんわん"
    else
      return "もふもふ"
    end
  end

  def generate_line_text_hash(input_text)
    return {
      type: 'text',
      text: generate_message(input_text)
    }
  end

  def call_bing_image_search_api(input_text)
    uri  = "https://api.cognitive.microsoft.com"
    path = "/bing/v7.0/images/search"
    
    uri = URI("#{uri}#{path}?q=#{URI.escape(input_text)}")
    
    request = Net::HTTP::Get.new(uri)
    request['Ocp-Apim-Subscription-Key'] = ENV["BING_IMAGE_API_KEY"]

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(request)
    end

    return JSON.parse(response.body)
  end

  def generate_line_image_hash(json)
    random_result = json.sample
    
    original_content_url = random_result["contentUrl"]
    preview_image_url = random_result["thumbnailUrl"]

    return {
      type: 'image',
      originalContentUrl: replace_to_https(original_content_url),
      previewImageUrl: replace_to_https(preview_image_url) + "&c=4&w=240&h=240"
    }
  end

  def generate_line_text_hash_when_image_not_found(input_text)
    return {
        type: 'text',
        text: "ごめんね #{0x100098.chr('UTF-8')} \n#{input_text}は見つからなかったみたい… \nちがうどうぶつの名前を入れてみて#{0x10005C.chr('UTF-8')}"
      }
  end

  def generate_line_massage_array(input_text)
    json_value = call_bing_image_search_api(input_text)["value"]
    if json_value.blank?
      return generate_line_text_hash_when_image_not_found(input_text)
    else
      return generate_line_image_carousel_hash(input_text, json_value.sample(10))
    end
  end

  def replace_to_https(url)
    return url.sub(/http:/, "https:")
  end

  def generate_line_image_carousel_columns_hash(json, input_text)
    return {
      imageUrl: replace_to_https(json["thumbnailUrl"]) + "&c=4&w=240&h=240",
      action: {
        type: "uri",
        label: generate_message(input_text),
        uri: json["hostPageUrl"]
      }
    }
  end

  def generate_line_image_carousel_columns_array(json, input_text)
    image_carousel_columns = Array.new
    for value in json
      image_carousel_columns.push(generate_line_image_carousel_columns_hash(value, input_text))
    end
    puts image_carousel_columns
    return image_carousel_columns
  end

  def generate_line_image_carousel_hash(input_text, json)
    return {
      type: 'template',
      altText: "#{input_text}の画像",
      template: {
        type: "image_carousel",
        columns: generate_line_image_carousel_columns_array(json, input_text)
      }
    }
  end
end