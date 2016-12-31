class Trader

  def start
    EM.run do
      EM.add_periodic_timer(1) {
        update_orders_and_contracts

        floor, ceiling = trading_range

        next if floor.nil? || ceiling.nil?

        if (floor..ceiling).include? current_price
          Contract.place_new_buy_order
          Contract.place_new_sell_order
        elsif current_price > ceiling
          price_jump(ceiling)
        elsif current_price < floor
          price_drop(floor)
        end
      }
      EM.error_handler { |e|
        p "Trader.start Error: #{e.message}"
        p "Trader.start Backtrace: #{e.backtrace}"
      }
    end
  end

  # TODO: move these methods to another class (GDAX::MarketData ?)

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

  def self.empty_orderbook
    OpenStruct.new({ bids: [[]], asks: [[]] })
  end

  #=================================================
    private
  #=================================================

    def current_price
      GDAX::MarketData.last_trade.price
    end

    def update_orders_and_contracts
      Order.update_status
      Contract.update_status
      Contract.resolve_open
    end

    def trading_range
      ma_15mins = GDAX::MarketData.calculate_average(15.minutes.ago)

      return if ma_15mins.nil? || current_price.nil?

      ceiling = ma_15mins * 1.002
      floor   = ma_15mins * 0.998

      [floor, ceiling]
    end

    def price_jump(ceiling)
      begin
        sleep 3
        if Trader.last_trade.price.to_d > ceiling
          puts "PRICE JUMP"
          puts "ceiling: #{ceiling}"
          puts "current_price: #{current_price}"
          puts "cancelling all open buy orders"
          # open_buys = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o['side'] == 'buy' }
          # open_buys.each do |open_order|
          #   order_id = open_order['id']
          #   cancellation = GDAX::Connection.new.rest_client.cancel(order_id)
          #   # confirm cancel completed successfully; rescue errors
          #   # cancellation returns empty hash {}
          #   if cancellation # or cancellation.empty?
          #     market_order = GDAX::Connection.new.rest_client.buy(0.01, nil, type: 'market')
          #     market_order = JSON.parse(market_order.to_json)
          #     # confirm market_order completed; rescue errors
          #     if ['pending', 'done'].include?(market_order['status'])
          #       contract      = Order.find_by(gdax_id: order_id).contract
          #       new_buy_order = Order.store_order(market_order, 'buy')
          #       contract.buy_order = new_buy_order
          #       puts "contract #{contract.id} dropped cancelled buy order #{order_id} and picked up market buy order #{new_buy_order.gdax_id}"
          #     end
          #   end
          # end
        end
      rescue StandardError => error
        puts "cancellation error: #{error.inspect}"
      end
    end

    def price_drop(floor)
      begin
        sleep 3
        if Trader.last_trade.price.to_d < floor
          puts "PRICE DROP"
          puts "floor: #{floor}"
          puts "current_price: #{current_price}"
          puts "cancelling all open sell orders"
          # open_sells = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o['side'] == 'sell' }
          # open_sells.each do |open_order|
          #   order_id = open_order['id']
          #   cancellation = GDAX::Connection.new.rest_client.cancel(order_id)
          #   # confirm cancel completed successfully; rescue errors
          #   # cancellation returns empty hash {}
          #   if cancellation # or cancellation.empty?
          #     market_order = GDAX::Connection.new.rest_client.sell(0.01, nil, type: 'market')
          #     market_order = JSON.parse(market_order.to_json)
          #     # confirm market_order completed; rescue errors
          #     if ['pending', 'done'].include?(market_order['status'])
          #       contract      = Order.find_by(gdax_id: order_id).contract
          #       new_sell_order = Order.store_order(market_order, 'sell')
          #       contract.sell_order = new_sell_order
          #       puts "contract #{contract.id} dropped cancelled sell order #{order_id} and picked up market sell order #{new_sell_order.gdax_id}"
          #     end
          #   end
          # end
        end
      rescue StandardError => error
        puts "cancellation error: #{error.inspect}"
      end
    end

end