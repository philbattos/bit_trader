class Market

  def self.poll
    while true
      Order.update_status
      sleep 0.3
      Contract.update_status
      sleep 0.3
      Contract.resolve_open
      sleep 0.3
      Contract.place_new_buy_order
      sleep 0.3
      Contract.place_new_sell_order
    end
  end

  def self.ticker
    GDAX.new.client.orderbook
  end

  def self.current_bid
    ticker.bids.first[0].to_f
  end

  def self.current_ask
    ticker.asks.first[0].to_f
  end

  #=================================================
    private
  #=================================================

    # def self.send_get_request(path, request_hash)
    #   http_client.get path do |request|
    #     request.headers['Content-Type']         = 'application/json'
    #     request.headers['CB-ACCESS-KEY']        = ENV['GDAX_API_KEY']
    #     request.headers['CB-ACCESS-SIGN']       = api_signature(request_hash)
    #     request.headers['CB-ACCESS-TIMESTAMP']  = timestamp
    #     request.headers['CB-ACCESS-PASSPHRASE'] = ENV['GDAX_API_PASSPHRASE']
    #   end
    # end

    # def self.http_client
    #   # move this into a module so it can be reused in multiple models
    #   Faraday.new(url: ENV['GDAX_BASE_URL']) do |faraday|
    #     # faraday.response :raise_error
    #     faraday.adapter  Faraday.default_adapter
    #   end
    # end

    # def self.timestamp
    #   Time.now.to_i.to_s
    #   # @timestamp ||= Time.now.to_i.to_s
    # end

    # def self.secret_hash
    #   Base64.decode64(ENV['GDAX_API_SECRET'])
    # end

    # def self.api_signature(request_hash)
    #   Base64.strict_encode64(request_hash)
    # end

end