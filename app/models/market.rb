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

    websocket = GDAX::Connection.new.websocket

    websocket.match do |response|
      # NOTE: response is a Coinbase::Exchange::APIObject
      GDAX::MarketData.save_trade(response)
      if response.trade_id % 100 == 0
        p "Latest Trade: $ %.2f (trade ID: #{response.trade_id})" % response.price
      end
    end

    EM.run do
      websocket.start!
      EM.add_periodic_timer(1) {
        Order.update_status
        Contract.update_status

        ma_15mins = GDAX::MarketData.calculate_average(15.minutes.ago)
        # mins30 = GDAX::MarketData.calculate_average(30.minutes.ago)
        # hours1 = GDAX::MarketData.calculate_average(1.hour.ago)
        # hours3 = GDAX::MarketData.calculate_average(3.hours.ago)
        current_price = GDAX::MarketData.last_trade.price

        next if ma_15mins.nil? || current_price.nil?

        ceiling = ma_15mins * 1.002
        floor   = ma_15mins * 0.998

        if (floor..ceiling).include? current_price
          Contract.resolve_open
          Contract.place_new_buy_order
          Contract.place_new_sell_order
        elsif current_price > ceiling
          puts "PRICE JUMP"
          puts "ceiling: #{ceiling}"
          puts "current_price: #{current_price}"
          sleep 1
          if last_trade.price.to_d > ceiling
            sleep 1
            if last_trade.price.to_d > ceiling
              begin
                puts "cancelling all open buy orders"
                open_buys = GDAX::Connection.rest_client.orders(status: 'open').select {|o| o['side'] == 'buy' }
                open_buys.each do |open_order|
                  order_id = open_order['id']
                  cancellation = GDAX::Connection.new.rest_client.cancel(order_id)
                  # confirm cancel completed successfully; rescue errors
                  # cancellation returns empty hash {}
                  if cancellation # or cancellation.empty?
                    market_order = GDAX::Connection.new.rest_client.buy(0.01, nil, type: 'market')
                    # confirm market_order completed; rescue errors
                    if ['pending', 'done'].include?(market_order['status'])
                      contract      = Order.find_by(gdax_id: order_id).contract
                      new_buy_order = Order.store_order(market_order, 'buy')
                      contract.buy_order = new_buy_order
                      puts "contract #{contract.id} dropped cancelled buy order #{order_id} and picked up market buy order #{new_buy_order.gdax_id}"
                    end
                  end
                end
              rescue StandardError => error
                puts "cancellation error: #{error.inspect}"
              end
            end
          end
        elsif current_price < floor
          puts "PRICE DROP"
          puts "floor: #{floor}"
          puts "current_price: #{current_price}"
          # retry a couple times to ensure that price decrease is not a temporary fluke
          # sell current sell orders
        end
      }
      EM.error_handler { |e|
        p "Websocket Error: #{e.message}"
      }
    end
  end

  def self.orderbook
    GDAX::Connection.new.rest_client.orderbook
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (orderbook): #{rate_limit_error}"
    empty_orderbook
  rescue Coinbase::Exchange::APIError => api_error
    puts "GDAX API error (orderbook): #{api_error}"
    empty_orderbook
  end

  def self.last_trade
    GDAX::Connection.new.rest_client.last_trade
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