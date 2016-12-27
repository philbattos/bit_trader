class Market

  def self.poll
    # while true
    #   Order.update_status
    #   sleep 0.4
    #   Contract.update_status
    #   sleep 0.4
    #   Contract.resolve_open
    #   # sleep 0.4
    #   # Contract.place_new_buy_order
    #   # sleep 0.4
    #   # Contract.place_new_sell_order
    # end

    # client = GDAX::Connection.new.async_client

    # EM.run {
    #   EM.add_periodic_timer(1) {
    #     # rest_api.last_trade(product_id: "BTC-GBP") do |resp|
    #     #   p "Spot Rate: £ %.2f" % resp.price
    #     # end
    #     # Order.update_status
    #     # Contract.update_status
    #     # Contract.resolve_open
    #     # Contract.place_new_buy_order
    #     # Contract.place_new_sell_order
    #     client.orderbook {|response| p response['asks'] }
    #   }
    # }

    websocket = GDAX::Connection.new.websocket

    websocket.match do |response|
      # NOTE: response is a Coinbase::Exchange::APIObject
      GDAX::MarketData.save_trade(response)
      if response.sequence % 1000 == 0
        p "Latest Trade: $ %.2f (seq: #{response.sequence})\n" % response.price
      end
    end

    EM.run do
      websocket.start!
      EM.add_periodic_timer(1) {
        # websocket.ping { p "Websocket is alive" }
      }
      EM.error_handler { |e|
        p "Websocket Error: #{e.message}"
      }
    end
  end

  def self.orderbook
    GDAX::Connection.new.async_client.orderbook
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (orderbook): #{rate_limit_error}"
    empty_orderbook
  rescue Coinbase::Exchange::APIError => api_error
    puts "GDAX API error (orderbook): #{api_error}"
    empty_orderbook
  end

  def self.last_trade
    GDAX::Connection.new.async_client.last_trade
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (last-trade): #{rate_limit_error}"
    empty_orderbook
  rescue Coinbase::Exchange::APIError => api_error
    puts "GDAX API error (last-trade): #{api_error}"
    empty_orderbook
  end

  def self.current_bid
    orderbook.bids.first[0].to_d
  rescue NoMethodError => no_method_error
    puts "NoMethodError (current_bid): #{no_method_error}"
    retry
  end

  def self.current_ask
    orderbook.asks.first[0].to_d
  rescue NoMethodError => no_method_error
    puts "NoMethodError (current_ask): #{no_method_error}"
    retry
  end

  #=================================================
    private
  #=================================================

    def self.empty_orderbook
      OpenStruct.new({ bids: [[]], asks: [[]] })
    end

end