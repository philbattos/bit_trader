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

        # send alert to frontend; or send email/text
        p "Restarting Trader.... \n\n"
        Trader.new.start
      }
    end
  end

  #=================================================
    private
  #=================================================

    def current_price
      GDAX::MarketData.last_saved_trade.price
    end

    def update_orders_and_contracts
      Order.update_status
      Contract.update_status
      Contract.resolve_open
      Order.cancel_stale_orders
    end

    def trading_range
      ma_15mins = GDAX::MarketData.calculate_average(15.minutes.ago)

      return if ma_15mins.nil? || current_price.nil?

      ceiling = ma_15mins * 1.005
      floor   = ma_15mins * 0.995

      [floor, ceiling]
    end

    def price_jump
      begin
        sleep 5
        # NOTE: recalculate ceiling because sometimes the number is wrong
        confirmed_ceiling = GDAX::MarketData.calculate_average(15.minutes.ago) * 1.002
        confirmed_price   = GDAX::MarketData.last_trade.price.to_d
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
        sleep 5
        # NOTE: recalculate floor because sometimes the number is wrong
        confirmed_floor = GDAX::MarketData.calculate_average(15.minutes.ago) * 0.998
        confirmed_price = GDAX::MarketData.last_trade.price.to_d
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
          order_id     = open_order['id']
          cancellation = GDAX::Connection.new.rest_client.cancel(order_id)
          # confirm cancel completed successfully; rescue errors
          # cancellation returns empty hash {}
          if cancellation # or cancellation.empty?
            order = Order.find_by(gdax_id: order_id)
            order.update(status: 'not-found', gdax_status: 'not-found')
            if order_type == 'buy'
              if order.contract.gdax_buy_order_id == order.gdax_id
                puts "removing gdax_buy_order_id from contract #{order.contract.id}"
                order.contract.update(gdax_buy_order_id: nil)
              end
            elsif order_type == 'sell'
              if order.contract.gdax_sell_order_id == order.gdax_id
                puts "removing gdax_sell_order_id from contract #{order.contract.id}"
                order.contract.update(gdax_sell_order_id: nil)
              end
            end
          end
        end
      end
    end

end