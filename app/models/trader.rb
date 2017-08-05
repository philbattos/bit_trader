class Trader < ActiveRecord::Base
  after_initialize :default_trader
  # NOTE: entry_short and entry_long should always be saved in minutes (not hours)

  def self.run
    Trader.find_by(name: 'default').start
  end

  def start
    EM.run do
      current_trader = Trader.find_by(name: name)
      EM.add_periodic_timer(1) {
        if current_trader.is_active
          update_orders_and_contracts
          place_new_orders
          Contract.add_new_contract
          technical_analysis_orders
        else
          # inactive trader
        end
        current_trader.reload
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

  def default_trader
    self.name = 'default'
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
      if waiting_for_entry?
        entry_short_time = entry_short.minutes.ago.time
        entry_long_time  = entry_long.minutes.ago.time

        # TO DO: Query Metrics table instead of MarketData for faster queries??
        short_line = GDAX::MarketData.calculate_exponential_average(entry_short_time)
        long_line  = GDAX::MarketData.calculate_exponential_average(entry_long_time)

        # TO DO: place stop orders once market price passes profit margin (multiply buy price * 1.0052 to cover fees)
        if short_line > (long_line * (1 + crossover_buffer)) # && Contract.trendline.without_active_sell.empty?
          # contract_id = Contract.trendline.with_sell_without_buy.first.try(:id)
          size        = trading_units
          price       = 1.00 # any number is sufficient since it is a 'market' order
          puts "Price is increasing... Placing new trendline BUY order."
          if Account.gdax_usdollar_account.available >= (GDAX::MarketData.current_ask * size * 1.01)
            Order.submit_order('buy', price, size, {type: 'market'}, nil, 'trendline')
          else
            puts "USD balance not sufficient for trendline BUY order."
          end
        elsif short_line < (long_line * (1 - crossover_buffer)) # && Contract.trendline.without_active_buy.empty?
          # contract_id = Contract.trendline.with_buy_without_sell.first.try(:id)
          size        = trading_units
          price       = 10000.00 # any number is sufficient since it is a 'market' order
          puts "Price is decreasing... Placing new trendline SELL order."
          if Account.gdax_bitcoin_account.available >= (size).to_d
            Order.submit_order('sell', price, size, {type: 'market'}, nil, 'trendline')
          else
            puts "BTC balance not sufficient for trendline SELL order."
          end
        end
      else # an entry trendline order has been placed. check the market conditions to place an exit order.
        exit_short_time = exit_short.minutes.ago.time
        exit_long_time  = exit_long.minutes.ago.time

        # TO DO: Query Metrics table instead of MarketData for faster queries??
        short_exit_line = GDAX::MarketData.calculate_exponential_average(exit_short_time)
        long_exit_line  = GDAX::MarketData.calculate_exponential_average(exit_long_time)

        contract = Contract.trendline.unresolved.first # there should only be 1 contract that needs an order
        if contract.lacking_sell?
          if short_exit_line < long_exit_line
            size  = trading_units # should match contract.buy_order.quantity
            price = 10000.00      # any number is sufficient since it is a 'market' order
            puts "Price is decreasing... Placing trendline SELL order for contract #{contract.id}."
            if Account.gdax_bitcoin_account.available >= (size).to_d
              Order.submit_order('sell', price, size, {type: 'market'}, contract.id, 'trendline')
            else
              puts "BTC balance not sufficient for matching trendline SELL order."
            end
          end
        elsif contract.lacking_buy?
          if short_exit_line > long_exit_line
            size  = trading_units # should match contract.sell_order.quantity
            price = 1.00          # any number is sufficient since it is a 'market' order
            puts "Price is increasing... Placing trendline BUY order for contract #{contract.id}."
            if Account.gdax_bitcoin_account.available >= (GDAX::MarketData.current_ask * size * 1.01)
              Order.submit_order('buy', price, size, {type: 'market'}, contract.id, 'trendline')
            else
              puts "BTC balance not sufficient for matching trendline BUY order."
            end
          end
        else
          Rails.logger.info "Trendline contract #{contract.id} could not be resolved. Maybe the contract does not have any orders?"
        end
      end
    end

    def waiting_for_entry?
      Contract.trendline.unresolved.empty?
    end

    def waiting_for_exit?
      Contract.trendline.unresolved.present?
    end

end