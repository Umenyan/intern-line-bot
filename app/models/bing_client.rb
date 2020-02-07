class BingClient
  # Bing Image Searsh APIを叩き、bodyをパースして返す
  def self.search_images(input_text)
    uri  = "https://api.cognitive.microsoft.com"
    path = "/bing/v7.0/images/search"
    
    uri = URI("#{uri}#{path}?q=#{URI.escape(input_text)}")
    
    request = Net::HTTP::Get.new(uri)
    request['Ocp-Apim-Subscription-Key'] = ENV["BING_IMAGE_API_KEY"]

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        http.request(request)
    end

    return JSON.parse(response.body)["value"]
  end

end