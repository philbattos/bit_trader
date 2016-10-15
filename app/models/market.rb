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

  def self.orderbook
    GDAX.new.client.orderbook
  end

  def self.last_trade
    GDAX.new.client.last_trade
  end

  def self.current_bid
    orderbook.bids.first[0].to_f
  end

  def self.current_ask
    orderbook.asks.first[0].to_f
  end

  #=================================================
    private
  #=================================================


end