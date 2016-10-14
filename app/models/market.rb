class Market

  def self.poll
    while true
      Order.update_status
      Contract.update_status
      Contract.resolve_open
      Contract.place_new_buy_order
      Contract.place_new_sell_order
    end
  end

  def self.fetch_ticker
    request_path = "/products/BTC-USD/ticker"
    request_info = "#{timestamp}GET#{request_path}"
    request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

    response = send_get_request(request_path, request_hash)

    puts "response: #{response.inspect}"
    if response.status == 200
      ticker = JSON.parse(response.body, symbolize_names: true)
    else
      ticker = nil
    end
    ticker
  end

  def self.current_bid
    puts "fetch_ticker: #{fetch_ticker.inspect}"
    fetch_ticker[:bid].to_f if !fetch_ticker.nil?
  end

  def self.current_ask
    puts "fetch_ticker: #{fetch_ticker.inspect}"
    fetch_ticker[:ask].to_f if !fetch_ticker.nil?
  end

  #=================================================
    private
  #=================================================

    def self.send_get_request(path, request_hash)
      http_client.get path do |request|
        request.headers['Content-Type']         = 'application/json'
        request.headers['CB-ACCESS-KEY']        = ENV['GDAX_API_KEY']
        request.headers['CB-ACCESS-SIGN']       = api_signature(request_hash)
        request.headers['CB-ACCESS-TIMESTAMP']  = timestamp
        request.headers['CB-ACCESS-PASSPHRASE'] = ENV['GDAX_API_PASSPHRASE']
      end
    end

    def self.http_client
      # move this into a module so it can be reused in multiple models
      Faraday.new(url: ENV['GDAX_BASE_URL']) do |faraday|
        # faraday.response :raise_error
        faraday.adapter  Faraday.default_adapter
      end
    end

    def self.timestamp
      Time.now.to_i.to_s
      # @timestamp ||= Time.now.to_i.to_s
    end

    def self.secret_hash
      Base64.decode64(ENV['GDAX_API_SECRET'])
    end

    def self.api_signature(request_hash)
      Base64.strict_encode64(request_hash)
    end

end