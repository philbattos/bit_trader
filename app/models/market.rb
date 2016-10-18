class Market

  def self.poll
    while true
      Order.update_status
      sleep 0.4
      Contract.update_status
      sleep 0.4
      Contract.resolve_open
      sleep 0.4
      Contract.place_new_buy_order
      sleep 0.4
      Contract.place_new_sell_order
    end
  end

  def self.orderbook
    GDAX.new.client.orderbook
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (orderbook): #{rate_limit_error}"
    empty_orderbook
  rescue Coinbase::Exchange::APIError => api_error
    puts "GDAX API error (orderbook): #{api_error}"
    empty_orderbook
  end

  def self.last_trade
    GDAX.new.client.last_trade
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (last-trade): #{rate_limit_error}"
    empty_orderbook
  rescue Coinbase::Exchange::APIError => api_error
    puts "GDAX API error (last-trade): #{api_error}"
    empty_orderbook
  end

  def self.current_bid
    orderbook.bids.first[0].to_f
  rescue NoMethodError => no_method_error
    puts "NoMethodError (current_bid): #{no_method_error}"
    retry
  end

  def self.current_ask
    orderbook.asks.first[0].to_f
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