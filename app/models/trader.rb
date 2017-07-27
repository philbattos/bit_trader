class Trader

  def start
    EM.run do
      EM.add_periodic_timer(1) {
        update_orders_and_contracts
        place_new_orders
        Contract.add_new_contract
        technical_analysis_orders
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
      # Order.cancel_stale_orders
    end

    def update_unresolved_order
      order = Order.unresolved.sample
      order.update_order if order
    end

    def place_new_orders
      return false if Contract.incomplete.count > 3

      # ma_15mins = GDAX::MarketData.calculate_average(15.minutes.ago)
      ma_30mins = GDAX::MarketData.calculate_average(30.minutes.ago)
      ma_4hours = GDAX::MarketData.calculate_average(4.hours.ago)

      return false if ma_30mins.nil? || ma_4hours.nil?

      ceiling = ma_4hours * 1.01
      floor   = ma_4hours * 0.99

      if (floor..ceiling).include?(ma_30mins)
        Contract.place_new_buy_order
        # Contract.place_new_sell_order
      else
        puts "Volatile market. 30min average: #{ma_30mins}, 4-hour average: #{ma_4hours}, trading range: #{floor.round(2)} - #{ceiling.round(2)}"
      end

      # Contract.logarithmic_buy
      # Contract.logarithmic_sell
    end

    def technical_analysis_orders
      # TO DO: Prevent queries from being run on every cycle. They slow down other bot actions.
      ma_13hours = GDAX::MarketData.calculate_exponential_average(13.hours.ago.time)
      ma_43hours = GDAX::MarketData.calculate_exponential_average(43.hours.ago.time)

      if ma_13hours > ma_43hours && Contract.trendline.without_active_sell.empty?
        contract_id = Contract.trendline.with_sell_without_buy.first.try(:id)
        size        = 0.02
        price       = 1.00 # any number is sufficient since it is a 'market' order
        puts "Price is increasing... Placing new trendline BUY order for contract #{contract_id}."
        if Account.gdax_usdollar_account.available >= (GDAX::MarketData.current_ask * size * 1.01)
          Order.submit_order('buy', price, size, {type: 'market'}, contract_id, 'trendline')
        else
          puts "USD balance not sufficient for trendline BUY order."
        end
      elsif ma_13hours < ma_43hours && Contract.trendline.without_active_buy.empty?
        contract_id = Contract.trendline.with_buy_without_sell.first.try(:id)
        size        = 0.02
        price       = 10000.00 # any number is sufficient since it is a 'market' order
        puts "Price is decreasing... Placing new trendline SELL order for contract #{contract_id}."
        if Account.gdax_bitcoin_account.available >= (size).to_d
          Order.submit_order('sell', price, size, {type: 'market'}, contract_id, 'trendline')
        else
          puts "BTC balance not sufficient for trendline SELL order."
        end
      end
    end

end