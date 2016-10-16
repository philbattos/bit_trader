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
  end

  def self.last_trade
    GDAX.new.client.last_trade
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (last-trade): #{rate_limit_error}"
    empty_orderbook
  end

  def self.current_bid
    @current_bid ||= orderbook.bids.first[0].to_f
  end

  def self.current_ask
    @current_ask ||= orderbook.asks.first[0].to_f
  end

  #=================================================
    private
  #=================================================

    def self.empty_orderbook
      OpenStruct.new({ bids: [[]], asks: [[]] })
    end

end