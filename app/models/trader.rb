class Trader

  def start
    EM.run do
      EM.add_periodic_timer(1) {
        update_orders_and_contracts
        place_new_orders
      }
      EM.error_handler do |e|
        json = JSON.parse(e.message)

        if json['message'] == 'request timestamp expired'
          puts "Timestamp expiration error. Restarting Trader"
          Trader.new.start
        else
          puts "Unrecognized Trader error"
          puts "e: #{e.message.inspect}"
          puts "json: #{json.inspect}"
          puts "Trader.start Backtrace: #{e.backtrace}"
        end

        # send alert to frontend; or send email/text
      end
    end
  end

  #=================================================
    private
  #=================================================

    def update_orders_and_contracts
      update_unresolved_order
      Contract.update_status # updates random 'done' contract; updates random liquidatable contract
      # Contract.market_maker.resolve_open
      Contract.resolve_open # liquidates old contracts; populates empty contracts with a buy order; matches open orders
      Order.cancel_stale_orders
    end

    def update_unresolved_order
      order = Order.unresolved.sample
      order.update_order if order
    end

    def place_new_orders
      ma_15mins = GDAX::MarketData.calculate_average(15.minutes.ago)
      ma_4hours = GDAX::MarketData.calculate_average(4.hours.ago)

      return false if ma_15mins.nil? || ma_4hours.nil?

      ceiling = ma_4hours * 1.002
      floor   = ma_4hours * 0.998

      if (floor..ceiling).include?(ma_15mins) && Contract.incomplete.count <= 3
        Contract.place_new_buy_order
        Contract.place_new_sell_order
      else
        puts "Volatile market. 15min average: #{ma_15mins}, 4-hour average: #{ma_4hours}, trading range: #{floor.round(2)} - #{ceiling.round(2)}"
      end

      # Contract.logarithmic_buy
      # Contract.logarithmic_sell
    end

end