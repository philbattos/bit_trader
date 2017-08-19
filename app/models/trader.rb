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
          # place_new_orders
          # Contract.add_new_contract
          technical_analysis_orders
        else
          # inactive trader
        end
        current_trader.reload
      }
      EM.error_handler do |e|
        json = JSON.parse(e.message)

        if json['message'] == 'request timestamp expired'
          Rails.logger.info "Timestamp expiration error. Restarting Trader"
          Trader.new.start
        else
          Rails.logger.info "Unrecognized Trader error"
          Rails.logger.info "e: #{e.message.inspect}"
          Rails.logger.info "json: #{json.inspect}"
          Rails.logger.info "Trader.start Backtrace: #{e.backtrace}"
        end

        # send alert to frontend; or send email/text
      end
    end
  end

  def default_trader
    self.name = 'default'
  end

  def market_conditions
    exit_short_time  = exit_short.minutes.ago.time
    exit_long_time   = exit_long.minutes.ago.time
    exit_short_line  = GDAX::MarketData.calculate_exponential_average(exit_short_time)
    exit_long_line   = GDAX::MarketData.calculate_exponential_average(exit_long_time)

    exit_medium_line = GDAX::MarketData.calculate_exponential_average(240.minutes.ago)

    entry_short_time = entry_short.minutes.ago.time
    entry_long_time  = entry_long.minutes.ago.time
    entry_short_line = GDAX::MarketData.calculate_exponential_average(entry_short_time)
    entry_long_line  = GDAX::MarketData.calculate_exponential_average(entry_long_time)

    return if [exit_short_line, exit_medium_line, exit_long_line, entry_short_line, entry_long_line].any? {|x| x.nil? || x == 0}

    market_conditions = {}
    market_conditions["#{exit_short.to_i}mins>240mins"]                 = exit_short_line > exit_medium_line
    market_conditions["240mins>#{entry_short.to_i}mins"]                = exit_medium_line > entry_short_line
    market_conditions["#{entry_short.to_i}mins>#{exit_long.to_i}mins"]  = entry_short_line > exit_long_line
    market_conditions["#{entry_short.to_i}mins>#{entry_long.to_i}mins"] = entry_short_line > entry_long_line
    market_conditions
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
        Rails.logger.info "Volatile market. 30min average: #{ma_30mins}, 4-hour average: #{ma_4hours}, trading range: #{floor.round(2)} - #{ceiling.round(2)}"
      end

      # Contract.logarithmic_buy
      # Contract.logarithmic_sell
    end

    def technical_analysis_orders
      current_conditions ||= market_conditions
      current_ask        ||= GDAX::MarketData.current_ask
      current_bid        ||= GDAX::MarketData.current_bid
      algorithm          ||= "enter#{entry_short.to_i}x#{entry_long.to_i}(#{crossover_buffer})~exit#{exit_short.to_i}x#{exit_long.to_i}~#{trading_units}units"

      if waiting_for_entry?
        # TO DO: if a trendline contract was recently exited and market is trending in the wrong direction, consider not entering a new trendline contract.

        entry_short_time = entry_short.minutes.ago.time
        entry_long_time  = entry_long.minutes.ago.time

        # TO DO: Query Metrics table instead of MarketData for faster queries??
        entry_short_line = GDAX::MarketData.calculate_exponential_average(entry_short_time)
        entry_long_line  = GDAX::MarketData.calculate_exponential_average(entry_long_time)

        # TO DO: place stop orders once market price passes profit margin (multiply buy price * 1.0052 to cover fees)
        # if entry_short_line > (entry_long_line * (1 + crossover_buffer)) && (exit_short_line > exit_long_line)
        # if current_conditions.values.all? {|value| value == true }
        #   size  = trading_units
        #   price = 1.00 # any number is sufficient since it is a 'market' order
        #   Rails.logger.info "Price is increasing... Placing new trendline BUY order."
        #   Rails.logger.info "current_conditions: #{current_conditions.inspect}"
        #   if Account.gdax_usdollar_account.available >= (GDAX::MarketData.current_ask * size * 1.01)
        #     Order.submit_order('buy', price, size, {type: 'market'}, nil, 'trendline', algorithm)
        #   else
        #     Rails.logger.info "USD balance not sufficient for trendline BUY order."
        #   end
        # elsif current_conditions.values.all? {|value| value == false }
        #   size  = trading_units
        #   price = 10000.00 # any number is sufficient since it is a 'market' order
        #   Rails.logger.info "Price is decreasing... Placing new trendline SELL order."
        #   Rails.logger.info "current_conditions: #{current_conditions.inspect}"
        #   if Account.gdax_bitcoin_account.available >= (size).to_d
        #     Order.submit_order('sell', price, size, {type: 'market'}, nil, 'trendline', algorithm)
        #   else
        #     Rails.logger.info "BTC balance not sufficient for trendline SELL order."
        #   end
        # end
        if current_conditions.values.all? {|value| value == true }
          Rails.logger.info "Price is increasing... Placing new trendline BUY order."
          Rails.logger.info "current_conditions: #{current_conditions.inspect}"

          open_buy_order = Order.my_highest_open_buy_order
          if open_buy_order && (open_buy_order.price > (GDAX::MarketData.current_bid * 0.9999))
            # do nothing
          else
            # cancel open buy order and place a new one
            Order.find_by(gdax_id: open_buy_order.id).cancel_order if open_buy_order
            size = trading_units
            if Account.gdax_usdollar_account.available >= (GDAX::MarketData.current_ask * size * 1.01)
              price = GDAX::MarketData.current_bid - 0.01
              Rails.logger.info "Attempting to place a new buy order at #{price} to avoid fees."
              Order.submit_order('buy', price, size, {post_only: true}, nil, 'trendline', algorithm)
            else
              Rails.logger.info "USD balance not sufficient for trendline BUY order."
            end
          end
        elsif current_conditions.values.all? {|value| value == false }
          Rails.logger.info "Price is decreasing... Placing new trendline SELL order."
          Rails.logger.info "current_conditions: #{current_conditions.inspect}"

          open_sell_order = Order.my_lowest_open_sell_order
          if open_sell_order && (open_sell_order.price < (GDAX::MarketData.current_ask * 1.0001))
            # do nothing
          else
            # cancel open sell order and place new one
            Order.find_by(gdax_id: open_sell_order.id).cancel_order if open_sell_order
            size = trading_units
            if Account.gdax_bitcoin_account.available >= (size).to_d
              price = GDAX::MarketData.current_ask + 0.01
              Rails.logger.info "Attempting to place a new sell order at #{price} to avoid fees."
              Order.submit_order('sell', price, size, {post_only: true}, nil, 'trendline', algorithm)
            else
              Rails.logger.info "BTC balance not sufficient for trendline SELL order."
            end
          end
        end
      else # an entry trendline order has been made previously. check the market conditions to make an exit order.
        contract        = Contract.trendline.unresolved.first # there should only be 1 contract that needs an order
        exit_short_time = exit_short.minutes.ago.time
        exit_long_time  = exit_long.minutes.ago.time
        exit_short_line ||= GDAX::MarketData.calculate_exponential_average(exit_short_time)
        exit_long_line  ||= GDAX::MarketData.calculate_exponential_average(exit_long_time)

        # if Contract.trendline.matched.any?
        #   Rails.logger.info "There is a matched trendline contract #{contract.id} that needs to update its status."
        #   return
        # end

        #   if contract.lacking_sell?
        #     if exit_short_line < exit_long_line
        #       size  = contract.buy_order.gdax_filled_size.to_d # should match contract.buy_order.quantity
        #       price = GDAX::MarketData.current_ask + 0.01
        #       Rails.logger.info "Price is decreasing... Placing trendline SELL order for contract #{contract.id}."
        #       if Account.gdax_bitcoin_account.available >= (size).to_d
        #         Order.submit_order('sell', price, size, {post_only: true}, contract.id, 'trendline', algorithm)
        #       else
        #         Rails.logger.info "BTC balance not sufficient for matching trendline SELL order."
        #       end
        #     end
        #   elsif contract.lacking_buy?
        #     if exit_short_line > exit_long_line
        #       size  = contract.sell_order.gdax_filled_size.to_d # should match contract.sell_order.quantity
        #       price = GDAX::MarketData.current_bid - 0.01
        #       Rails.logger.info "Price is increasing... Placing trendline BUY order for contract #{contract.id}."
        #       if Account.gdax_usdollar_account.available >= (GDAX::MarketData.current_ask * size * 1.01)
        #         Order.submit_order('buy', price, size, {post_only: true}, contract.id, 'trendline', algorithm)
        #       else
        #         Rails.logger.info "USD balance not sufficient for matching trendline BUY order."
        #       end
        #     end
        #   else
        #     Rails.logger.info "Trendline contract #{contract.id} could not be resolved. Maybe the contract does not have any orders?"
        #   end
        # end

        # NOTE: a trendline contract should only have one active order at a time.
        if contract.buy_order
          buy_order = contract.buy_order
          if buy_order.done?
            if contract.sell_order # if we already have a sell order, we must have previously received a 'sell' signal, so we don't need to check the market conditions again; we should complete a sell order ASAP.
              sell_order = contract.sell_order
              if sell_order.done?
                Rails.logger.info "The contract #{contract.id} has a buy and sell order marked as 'done'. Waiting for its status to be updated."
              else # contract has a sell order but it is not 'done'
                if sell_order.requested_price < (current_ask * 1.0001)
                  Rails.logger.info "The contract #{contract.id} has an active sell order with a price of #{sell_order.requested_price.round(2)}, which is within .01\% of the market price #{current_ask.round(2)}."
                else # contract's sell order is out of range; it needs to be canceled and replaced
                  Rails.logger.info "The contract #{contract.id} has an active sell order with a price of #{sell_order.requested_price.round(2)}, which is higher than the market #{current_ask.round(2)}. Canceling sell order #{sell_order.id}."
                  if sell_order.cancel_order
                    price = current_ask + 0.01
                    size  = buy_order.gdax_filled_size.to_d
                    Rails.logger.info "Sell order #{sell_order.id} successfully canceled. Placing new SELL order for #{size} BTC at $#{price}."
                    place_trendline_sell(price, size, contract.id, algorithm)
                  end
                end
              end
            else # contract doesn't have a sell order
              # if exit_short_line < exit_long_line
              if GDAX::MarketData.current_trend(6.hours.ago, 60) == 'TRENDING DOWN'
                Rails.logger.info "Price is decreasing... Placing exit SELL order for contract #{contract.id}."
                price = current_ask + 0.01
                size  = buy_order.gdax_filled_size.to_d
                if Account.gdax_bitcoin_account.available >= size.to_d
                  place_trendline_sell(price, size, contract.id, algorithm)
                else
                  Rails.logger.info "BTC balance not sufficient for matching trendline SELL order of #{size}."
                end
              else
                # Rails.logger.info "Waiting for market conditions to support an exit SELL... current price: #{current_ask}"
              end
            end
          else # buy order is active but not 'done'
            if buy_order.requested_price > (current_bid * 0.9999)
              Rails.logger.info "The contract #{contract.id} has an active buy order with a price of #{buy_order.requested_price.round(2)}, which is within .01\% of the market price #{current_bid.round(2)}."
            else # contract's buy order is out of range; it needs to be canceled and replaced
              Rails.logger.info "The contract #{contract.id} has an active buy order with a price of #{buy_order.requested_price.round(2)}, which is higher than the market #{current_bid.round(2)}. Canceling buy order #{buy_order.id}."
              if buy_order.cancel_order
                price = current_bid - 0.01
                size  = contract.sell_order ? contract.sell_order.gdax_filled_size.to_d : 0.20
                Rails.logger.info "Buy order #{buy_order.id} successfully canceled. Placing new BUY order for #{size} BTC at $#{price}."
                place_trendline_buy(price, size, contract.id, algorithm)
              end
            end
          end
        elsif contract.sell_order
          sell_order = contract.sell_order
          if sell_order.done?
            # if exit_short_line > exit_long_line
            if GDAX::MarketData.current_trend(6.hours.ago, 60) == 'TRENDING UP'
              Rails.logger.info "Price is increasing... Placing exit BUY order for contract #{contract.id}."
              price = current_bid - 0.01
              size  = sell_order.gdax_filled_size.to_d
              if Account.gdax_usdollar_account.available >= (current_ask * size * 1.01)
                place_trendline_buy(price, size, contract.id, algorithm)
              else
                Rails.logger.info "USD balance not sufficient for matching trendline BUY order of #{size}."
              end
            else
              # Rails.logger.info "Waiting for market conditions to support an exit BUY... current price: #{current_bid}"
            end
          else # contract has a sell order that is active but not 'done'; no buy order
            if sell_order.requested_price < (current_ask * 1.0001)
              Rails.logger.info "The contract #{contract.id} has an active sell order with a price of #{sell_order.requested_price.round(2)}, which is within .01\% of the market price #{current_ask.round(2)}."
            else # contract's sell order is out of range; it needs to be canceled and replaced
              Rails.logger.info "The contract #{contract.id} has an active sell order with a price of #{sell_order.requested_price.round(2)}, which is higher than the market #{current_ask.round(2)}. Canceling sell order #{sell_order.id}."
              if sell_order.cancel_order
                price = current_ask + 0.01
                size  = 0.20
                Rails.logger.info "Sell order #{sell_order.id} successfully canceled. Placing new SELL order for #{size} BTC at $#{price}."
                place_trendline_sell(price, size, contract.id, algorithm)
              end
            end
          end
        else # contract without buy or sell
          Rails.logger.info "The contract #{contract.id} has no buy order and no sell order. Marking it as 'retired'."
          contract.update(status: 'retired')
        end
      end
    end

    def waiting_for_entry?
      Contract.trendline.unresolved.empty?
    end

    def place_trendline_buy(price, size, contract_id, algorithm)
      Rails.logger.info "Attempting to place a new buy order for contract #{contract_id} to avoid fees: #{size} BTC at #{price} USD."
      Order.submit_order('buy', price, size, {post_only: true}, contract_id, 'trendline', algorithm)
    end

    def place_trendline_sell(price, size, contract_id, algorithm)
      Rails.logger.info "Attempting to place a new sell order for contract #{contract_id} to avoid fees: #{size} BTC at #{price} USD."
      Order.submit_order('sell', price, size, {post_only: true}, contract_id, 'trendline', algorithm)
    end

end