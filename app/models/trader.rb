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
          price_jump
        elsif current_price < floor
          price_drop
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

    def price_jump
      begin
        sleep 3
        # NOTE: recalculate ceiling because sometimes the number is wrong
        confirmed_ceiling = GDAX::MarketData.calculate_average(15.minutes.ago) * 1.002
        confirmed_price   = Trader.last_trade.price.to_d
        if confirmed_price > confirmed_ceiling
          puts "PRICE JUMP"
          puts "ceiling: #{confirmed_ceiling}"
          puts "current_price: #{confirmed_price}"
          puts "cancelling all open buy orders"
          cancel_orders('buy')
        end
      rescue StandardError => error
        puts "cancellation error: #{error.inspect}"
      end
    end

    def price_drop
      begin
        sleep 3
        # NOTE: recalculate floor because sometimes the number is wrong
        confirmed_floor = GDAX::MarketData.calculate_average(15.minutes.ago) * 0.998
        confirmed_price = Trader.last_trade.price.to_d
        if confirmed_price < confirmed_floor
          puts "PRICE DROP"
          puts "floor: #{confirmed_floor}"
          puts "current_price: #{confirmed_price}"
          puts "cancelling all open sell orders"
          cancel_orders('sell')
        end
      rescue StandardError => error
        puts "cancellation error: #{error.inspect}"
      end
    end

    def cancel_orders(order_type)
      open_sells = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o['side'] == order_type }
      open_sells.each_with_index do |open_order, index|
        if index.even? # let's cancel half of the open orders
          order_id = open_order['id']
          cancellation = GDAX::Connection.new.rest_client.cancel(order_id)
          # confirm cancel completed successfully; rescue errors
          # cancellation returns empty hash {}
          if cancellation # or cancellation.empty?
            order = Order.find_by(gdax_id: order_id)
            order.update(status: 'not-found')
          end
        end
      end
    end

end