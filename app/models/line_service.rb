class LineService
  def validate_signature(body, signature)
    client.validate_signature(body, signature)
  end

  def call(body)
    events = client.parse_events_from(body)
    events.each { |event|
      case event
      when Line::Bot::Event::Message
        #テキストメッセージなら画像を返し、そうでなければ再入力を促す
        case event.type
        when Line::Bot::Event::MessageType::Text
          input_text = event.message['text'].downcase
          client.reply_message(event['replyToken'], generate_line_massage_array(input_text))
        else
          message = {
            type: 'text',
            text: "テキストメッセージにしかお返事できないんだ #{0x100018.chr('UTF-8')} \nごめんね #{0x100029.chr('UTF-8')}#{0x100029.chr('UTF-8')} \nテキストでどうぶつの名前を入れてみて#{0x10005F.chr('UTF-8')}"
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    }
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
  #入力されたテキストに応じて鳴き声のようなものを生成
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

  # LINEのAPIで鳴き声のようなものを返すためのハッシュを生成
  def generate_line_text_hash(input_text)
    return {
      type: 'text',
      text: generate_message(input_text)
    }
  end

  # BingのAPIから画像が返って来なかった場合のメッセージ送信
  def generate_line_text_hash_when_image_not_found(input_text)
    return {
        type: 'text',
        text: "ごめんね #{0x100098.chr('UTF-8')} \n#{input_text}は見つからなかったみたい… \nちがうどうぶつの名前を入れてみて#{0x10005C.chr('UTF-8')}"
      }
  end

  # LINE APIでスタンプを送るためのハッシュを生成
  def generate_line_sticker_hash(packageId, stickerId)
    return{
      type: 'sticker',
      packageId: packageId,
      stickerId: stickerId
    }
  end

  # LINEのAPIに渡すリプライ用のメッセージの配列
  def generate_line_massage_array(input_text)
    bing_clients = BingClient.search_images(input_text)
    if bing_clients.blank?
      return [generate_line_text_hash_when_image_not_found(input_text), generate_line_sticker_hash(11539, 52114110)]
    else
      return generate_line_image_carousel_hash(input_text, bing_clients.sample(10))
    end
  end

  # httpをhttpsに書き換えるだけのもの
  def replace_to_https(url)
    return url.sub(/http:/, "https:")
  end

  # LINEのAPIの画像カルーセルテンプレートに渡す画像情報(カラム)のハッシュを生成
  def generate_line_image_carousel_columns_hash(bing_client, input_text)
    return {
      imageUrl: replace_to_https(bing_client.thumbnail_url) + "&c=4&w=240&h=240", # LINEの画像カルーセルは1:1比しか受け付けてくれない 
      action: {
        type: "uri",
        label: generate_message(input_text),
        uri: bing_client.host_page_url
      }
    }
  end

  # LINEのAPIの画像カルーセルテンプレートに渡す画像情報(カラム)の配列をBingのAPIから返されたJSONに基づいて生成
  def generate_line_image_carousel_columns_array(json, input_text)
    image_carousel_columns  = json.map do |value|
      generate_line_image_carousel_columns_hash(value, input_text)
    end
    return image_carousel_columns
  end

  # LINEのAPIに画像カルーセルを渡すためのハッシュを生成
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
