class Trader < ActiveRecord::Base
  after_initialize :default_trader
  # NOTE: entry_short and entry_long should always be saved in minutes (not hours)

  # STOP_ORDER_MIN = 0.003
  # STOP_ORDER_MAX = 0.0045
  STOP_ORDER_PERCENT = 0.02

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
        elsif json['message'] == 'Internal server error'
          Rails.logger.info "GDAX internal server error. Restarting Trader"
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
    one_hour_trend   = GDAX::MarketData.current_trend(1.hours.ago, 300)
    four_hour_trend  = GDAX::MarketData.current_trend(4.hours.ago, 300)
    six_hour_trend   = GDAX::MarketData.current_trend(6.hours.ago, 300)
    eight_hour_trend = GDAX::MarketData.current_trend(8.hours.ago, 300)
    ten_hour_trend   = GDAX::MarketData.current_trend(10.hours.ago, 300)
    breakthrough     = true  if GDAX::MarketData.new_high_price?(12.hours.ago)
    breakthrough     = false if GDAX::MarketData.new_low_price?(12.hours.ago)

    case one_hour_trend
    when 'TRENDING UP'
      trend_1hour = true
    when 'TRENDING DOWN'
      trend_1hour = false
    end

    case four_hour_trend
    when 'TRENDING UP'
      trend_4hour = true
    when 'TRENDING DOWN'
      trend_4hour = false
    end

    case six_hour_trend
    when 'TRENDING UP'
      trend_6hour = true
    when 'TRENDING DOWN'
      trend_6hour = false
    end

    case eight_hour_trend
    when 'TRENDING UP'
      trend_8hour = true
    when 'TRENDING DOWN'
      trend_8hour = false
    end

    case ten_hour_trend
    when 'TRENDING UP'
      trend_10hour = true
    when 'TRENDING DOWN'
      trend_10hour = false
    end

    return if [exit_short_line, exit_medium_line, exit_long_line, entry_short_line, entry_long_line].any? {|x| x.nil? || x == 0}

    market_conditions = {}
    market_conditions["#{exit_short.to_i}mins>240mins"]                 = exit_short_line > exit_medium_line
    market_conditions["240mins>#{entry_short.to_i}mins"]                = exit_medium_line > entry_short_line
    market_conditions["#{entry_short.to_i}mins>#{exit_long.to_i}mins"]  = entry_short_line > exit_long_line
    market_conditions["#{entry_short.to_i}mins>#{entry_long.to_i}mins"] = entry_short_line > entry_long_line
    market_conditions["1hour_trend"]                                    = trend_1hour
    market_conditions["4hour_trend"]                                    = trend_4hour
    market_conditions["6hour_trend"]                                    = trend_6hour
    market_conditions["8hour_trend"]                                    = trend_8hour
    market_conditions["10hour_trend"]                                   = trend_10hour
    market_conditions["breakthrough"]                                   = breakthrough
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
      # TODO: prevent partially filled orders from being canceled
      # TODO: figure out why so many contracts are getting changed to 'retired'

      current_conditions  ||= market_conditions
      current_ask         ||= GDAX::MarketData.current_ask
      current_bid         ||= GDAX::MarketData.current_bid
      algorithm           ||= "enter#{entry_short.to_i}x#{entry_long.to_i}(#{crossover_buffer})~exit#{exit_short.to_i}x#{exit_long.to_i}~#{trading_units}units"
      crossover_algorithm ||= 'ema_crossover_750_2500_minutes'

      # 13hour-43hour crossover algorithm
      ema_crossover_contracts = Contract.ema_cross_750_2500_min.unresolved
      ema750  ||= GDAX::MarketData.calculate_exponential_average(750.minutes.ago.time)
      ema2500 ||= GDAX::MarketData.calculate_exponential_average(2500.minutes.ago.time)

      if ema750.nil? || ema2500.nil?
        Rails.logger.info "EMA-750 is #{ema750}; EMA-2500 is #{ema2500}. Skipping EMA crossover algorithm."
      else
        if ema_crossover_contracts.none?
          if ema750 > (ema2500 * 1.0025)
            price = 1.00 # any number is sufficient since it is a 'market' order
            size  = 0.25
            Rails.logger.info "EMA 750min (#{ema750.round(2)}) has crossed above EMA 2500min (#{ema2500.round(2)})... Placing new market BUY order."
            Order.submit_order('buy', price, size, {type: 'market'}, nil, 'trendline', crossover_algorithm)
          elsif ema750 < (ema2500 * 0.9975)
            price = 10000.00 # any number is sufficient since it is a 'market' order
            size  = 0.25
            Rails.logger.info "EMA 750min (#{ema750.round(2)}) has crossed under EMA 2500min (#{ema2500.round(2)})... Placing new market SELL order."
            Order.submit_order('sell', price, size, {type: 'market'}, nil, 'trendline', crossover_algorithm)
          else # ema lines are too close
            # do nothing
          end
        else
          ema_contract = ema_crossover_contracts.first
          return unless ema_contract.created_at < 5.minutes.ago # wait 5 minutes after contract is created to prevent placing multiple orders when EMA lines are fluttering near each other
          if ema_contract.buy_order.try(:done?) && ema_contract.sell_order.nil?
            if ema750 < (ema2500 * 1.0025)
              price = 10000.00 # any number is sufficient since it is a 'market' order
              size  = ema_contract.btc_quantity
              Rails.logger.info "EMA 750min (#{ema750.round(2)}) is approaching EMA 2500min (#{ema2500.round(2)})... Placing new market SELL order to fulfill contract #{ema_contract.id}."
              Order.submit_order('sell', price, size, {type: 'market'}, ema_contract.id, 'trendline', crossover_algorithm)
            end

          elsif ema_contract.sell_order.try(:done?) && ema_contract.buy_order.nil?
            if ema750 > (ema2500 * 0.9975)
              price = 1.00 # any number is sufficient since it is a 'market' order
              size  = ema_contract.btc_quantity
              Rails.logger.info "EMA 750min (#{ema750.round(2)}) is approaching EMA 2500min (#{ema2500.round(2)})... Placing new market BUY order to fulfill contract #{ema_contract.id}."
              Order.submit_order('buy', price, size, {type: 'market'}, ema_contract.id, 'trendline', crossover_algorithm)
            end
          else # something is weird
            Rails.logger.info "Waiting for EMA contract #{ema_contract.id} to be updated to 'done'."
          end
        end
      end

      if waiting_for_entry?
        entry_short_time = entry_short.minutes.ago.time
        entry_long_time  = entry_long.minutes.ago.time

        # TO DO: Query Metrics table instead of MarketData for faster queries??
        entry_short_line = GDAX::MarketData.calculate_exponential_average(entry_short_time)
        entry_long_line  = GDAX::MarketData.calculate_exponential_average(entry_long_time)

        if current_conditions.values.all? {|value| value == true }
          Rails.logger.info "Price is increasing... Placing new trendline BUY order."
          Rails.logger.info "current_conditions: #{current_conditions.inspect}"

          open_buy_order = Order.my_highest_open_buy_order
          if open_buy_order && (open_buy_order.price > (GDAX::MarketData.current_bid * 0.9999))
            # do nothing
          else
            # cancel open buy order and place a new one
            highest_buy_order = Order.find_by(gdax_id: open_buy_order.id)
            highest_buy_order.cancel_order if highest_buy_order
            size = trading_units # this value is stored in the Trader.new object
            if Account.gdax_usdollar_account.available >= (GDAX::MarketData.current_ask * size * 1.01)
              price = GDAX::MarketData.current_bid - 0.01
              Rails.logger.info "Attempting to place a new buy order at #{price} to avoid fees."
              Order.submit_order('buy', price, size, {post_only: true}, nil, 'trendline', algorithm)
            else
              Rails.logger.info "USD balance not sufficient for trendline BUY order."
            end
          end
        elsif current_conditions.values.all? {|value| value == false }
          # Rails.logger.info "Price is decreasing... Placing new trendline SELL order."
          # Rails.logger.info "current_conditions: #{current_conditions.inspect}"

          # open_sell_order = Order.my_lowest_open_sell_order
          # if open_sell_order && (open_sell_order.price < (GDAX::MarketData.current_ask * 1.0001))
          #   # do nothing
          # else
          #   # cancel open sell order and place new one
          #   Order.find_by(gdax_id: open_sell_order.id).cancel_order if open_sell_order
          #   size = trading_units
          #   if Account.gdax_bitcoin_account.available >= (size).to_d
          #     price = GDAX::MarketData.current_ask + 0.01
          #     Rails.logger.info "Attempting to place a new sell order at #{price} to avoid fees."
          #     Order.submit_order('sell', price, size, {post_only: true}, nil, 'trendline', algorithm)
          #   else
          #     Rails.logger.info "BTC balance not sufficient for trendline SELL order."
          #   end
          # end
        end
      else # an entry trendline order has been made previously. check the market conditions to make an exit order.
        contract        = Contract.trendline.non_ema_crossover.unresolved.first # there should only be 1 contract that needs an order
        exit_short_time = exit_short.minutes.ago.time
        exit_long_time  = exit_long.minutes.ago.time
        exit_short_line ||= GDAX::MarketData.calculate_exponential_average(exit_short_time)
        exit_long_line  ||= GDAX::MarketData.calculate_exponential_average(exit_long_time)

        if contract.buy_orders.active.where(stop_type: nil).any?
          buy_order = contract.buy_orders.active.where(stop_type: nil).first # NOTE: a trendline contract should only have one active order at a time.
          if buy_order.done?

            ##########   Place sell order   ##########
            if contract.sell_orders.active.where(stop_type: nil).any? # if we already have a sell order, we must have previously received a 'sell' signal, so we don't need to check the market conditions again; we should complete a sell order ASAP.
              sell_order = contract.sell_orders.active.where(stop_type: nil).first
              if sell_order.done?
                Rails.logger.info "The contract #{contract.id} has a buy and sell order marked as 'done'. Waiting for its status to be updated."
              else # contract has a sell order but it is not 'done'
                if sell_order.requested_price < (current_ask * 1.0001)
                  Rails.logger.info "The contract #{contract.id} has an active sell order with a price of #{sell_order.requested_price.round(2)}, which is within .01\% of the market price #{current_ask.round(2)}."
                else # contract's sell order is out of range; it needs to be canceled and replaced
                  Rails.logger.info "The contract #{contract.id} has an active sell order with a price of #{sell_order.requested_price.round(2)}, which is higher than the market #{current_ask.round(2)}. Canceling sell order #{sell_order.id}."
                  size = buy_order.gdax_filled_size.to_d
                  if sell_order.cancel_order # TODO: cancel order unless it has been partially filled
                    price = current_ask + 0.01
                    Rails.logger.info "Sell order #{sell_order.id} successfully canceled. Placing new SELL order for #{size} BTC at $#{price}."
                    place_trendline_sell(price, size, contract.id, algorithm)
                  end
                end
              end
            else # contract doesn't have a normal sell order; it might have a stop order
              if GDAX::MarketData.current_trend(10.hours.ago, 300) == 'TRENDING DOWN'
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

            ##########   Place stop order   ##########
            stop_order_floor         = (buy_order.filled_price * (1.0 - STOP_ORDER_MAX)).round(2)
            current_stop_order_price = (current_ask * (1.0 - STOP_ORDER_PERCENT)).round(2)

            if contract.sell_orders.active.stop_orders.any? # GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.type == 'limit' && o.stop == 'entry' && o.side == 'sell' }.any?
              return if contract.resolvable? # this handles an edge case where the stop order has filled and been updated to 'done' but the contract hasn't yet been updated
              active_stop_order = contract.sell_orders.active.stop_order.first # there should only be one active stop order
              if current_stop_order_price > (active_stop_order.stop_price * 0.0003)
                size = active_stop_order.quantity
                if active_stop_order.cancel_order
                  Rails.logger.info "Stop order #{active_stop_order.id} successfully canceled. Placing new SELL STOP order for #{size} BTC at $#{current_stop_order_price}."
                  place_trendline_buy(current_stop_order_price, size, contract.id, algorithm)
                end
              end
            else
              return if contract.resolvable? # this handles an edge case where the stop order has filled and been updated to 'done' but the contract hasn't yet been updated
              size = buy_order.gdax_filled_size.to_d
              place_stop_sell(stop_order_floor, stop_order_floor, size, contract.id, algorithm) # NOTE: the stop_order_price is the market price that will trigger the order; the limit_price is the price that it will be sold for
            end

          else # buy order is active but not 'done'
            if buy_order.requested_price > (current_bid * 0.9999)
              Rails.logger.info "The contract #{contract.id} has an active buy order with a price of #{buy_order.requested_price.round(2)}, which is within .01\% of the market price #{current_bid.round(2)}."
            else # contract's buy order is out of range; it needs to be canceled and replaced
              Rails.logger.info "The contract #{contract.id} has an active buy order with a price of #{buy_order.requested_price.round(2)}, which is lower than the market #{current_bid.round(2)}. Canceling buy order #{buy_order.id}."
              size = buy_order.quantity
              if buy_order.cancel_order # TODO: cancel order unless it has been partially filled
                price = current_bid - 0.01
                Rails.logger.info "Buy order #{buy_order.id} successfully canceled. Placing new BUY order for #{size} BTC at $#{price}."
                place_trendline_buy(price, size, contract.id, algorithm)
              end
            end
          end
        elsif contract.sell_orders.active.where(stop_type: nil).any?
          sell_order = contract.sell_orders.active.where(stop_type: nil).first
          if sell_order.done?
            if GDAX::MarketData.current_trend(10.hours.ago, 300) == 'TRENDING UP'
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

            ##########   Place stop order   ##########
            # stop_order_price = (sell_order.filled_price * (1.0 - STOP_ORDER_MAX)).round(2)
            # if contract.buy_orders.active.stop_orders.any?
            #   # if GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.type == 'limit' && o.stop == 'entry' && o.side == 'sell' }.any?
            #   # there is an active stop order; do nothing
            # elsif current_ask < (stop_order_price * 0.9995)
            #   return if contract.resolvable? # this handles an edge case where the stop order has filled and been updated to 'done' but the contract hasn't yet been updated
            #   size = sell_order.gdax_filled_size.to_d
            #   limit_price = (sell_order.filled_price * (1.0 - STOP_ORDER_MIN)).round(2)
            #   place_stop_buy(limit_price, stop_order_price, size, contract.id, algorithm)
            # end

          else # contract has a sell order that is active but not 'done'; no buy order
            if sell_order.requested_price < (current_ask * 1.0001)
              Rails.logger.info "The contract #{contract.id} has an active sell order with a price of #{sell_order.requested_price.round(2)}, which is within .01\% of the market price #{current_ask.round(2)}."
            else # contract's sell order is out of range; it needs to be canceled and replaced
              Rails.logger.info "The contract #{contract.id} has an active sell order with a price of #{sell_order.requested_price.round(2)}, which is higher than the market #{current_ask.round(2)}. Canceling sell order #{sell_order.id}."
              size = sell_order.quantity
              if sell_order.cancel_order # TODO: cancel order unless it has been partially filled
                price = current_ask + 0.01
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
      Contract.trendline.non_ema_crossover.unresolved.empty?
    end

    def place_trendline_buy(price, size, contract_id, algorithm)
      Rails.logger.info "Attempting to place a new buy order for contract #{contract_id} to avoid fees: #{size} BTC at #{price} USD."
      Order.submit_order('buy', price, size, {post_only: true}, contract_id, 'trendline', algorithm)
    end

    def place_trendline_sell(price, size, contract_id, algorithm)
      Rails.logger.info "Attempting to place a new sell order for contract #{contract_id} to avoid fees: #{size} BTC at #{price} USD."
      Order.submit_order('sell', price, size, {post_only: true}, contract_id, 'trendline', algorithm)
    end

    def place_stop_buy(limit_price, stop_price, size, contract_id, algorithm)
      Rails.logger.info "Attempting to place a new STOP buy (entry) order for contract #{contract_id}: #{size} BTC between #{limit_price}-#{stop_price} USD."
      Order.submit_order('buy', limit_price, size, {stop: 'entry', stop_price: stop_price}, contract_id, 'trendline', algorithm)
    end

    def place_stop_sell(limit_price, stop_price, size, contract_id, algorithm)
      Rails.logger.info "Attempting to place a new STOP sell (loss) order for contract #{contract_id}: #{size} BTC between #{limit_price}-#{stop_price} USD."
      Order.submit_order('sell', limit_price, size, {stop: 'loss', stop_price: stop_price}, contract_id, 'trendline', algorithm)
    end

end