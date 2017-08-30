class Contract < ActiveRecord::Base
  before_create { self.status = "new" unless self.status }

  has_many :buy_orders, class_name: 'BuyOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception
  has_many :sell_orders, class_name: 'SellOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception

  # NOTE: consider querying contracts based on presence of gdax_order_ids
  scope :retired,                -> { where(status: 'retired') }
  scope :liquidate,              -> { where(status: 'liquidate') }
  scope :trendline,              -> { where(strategy_type: 'trendline') }
  scope :market_maker,           -> { where(strategy_type: 'market-maker') }
  scope :adjust_balance,         -> { where(strategy_type: 'adjust-balance') }
  scope :active,                 -> { where.not(id: retired).where.not(id: adjust_balance) }
  scope :with_buy_orders,        -> { active.where(id: BuyOrder.select(:contract_id).distinct) }
  scope :with_sell_orders,       -> { active.where(id: SellOrder.select(:contract_id).distinct) }
  scope :without_buy_orders,     -> { active.where.not(id: with_buy_orders) }
  scope :without_sell_orders,    -> { active.where.not(id: with_sell_orders) }
  scope :with_active_buy,        -> { active.where(id: BuyOrder.active.select(:contract_id).distinct) }
  scope :with_active_sell,       -> { active.where(id: SellOrder.active.select(:contract_id).distinct) }
  scope :without_active_buy,     -> { active.where.not(id: with_active_buy) }
  scope :without_active_sell,    -> { active.where.not(id: with_active_sell) }
  scope :with_buy_without_sell,  -> { with_active_buy.without_active_sell }
  scope :with_sell_without_buy,  -> { with_active_sell.without_active_buy }
  scope :without_active_order,   -> { without_active_buy.without_active_sell } # this happens when an order is created and then canceled before it can be matched with another order
  scope :resolved,               -> { active.where(status: ['done']) }
  scope :unresolved,             -> { active.where.not(id: resolved) }
  scope :resolvable,             -> { matched.complete }
  scope :liquidatable,           -> { unresolved.where.not(id: liquidate).where("created_at < ?", 1.day.ago).where(id: Order.liquidatable.select(:contract_id)).distinct }
  # scope :liquidatable_sell,      -> { unresolved.where.not(id: liquidate).joins(:buy_orders).where("contracts.created_at < ?", 1.day.ago).where("orders.status = 'done' AND orders.requested_price NOT BETWEEN ? AND ?", Metric.seven_day_range.first, Metric.seven_day_range.last).distinct }
  # scope :liquidatable_buy,       -> { unresolved.where.not(id: liquidate).joins(:sell_orders).where("contracts.created_at < ?", 1.day.ago).where("orders.status = 'done' AND orders.requested_price NOT BETWEEN ? AND ?", Metric.seven_day_range.first, Metric.seven_day_range.last).distinct }
  # scope :liquidatable_all,       -> { unresolved.where.not(id: liquidate).joins(:buy_orders, :sell_orders).where("contracts.created_at < ?", 1.day.ago).where.not("orders.status = 'done' AND orders.requested_price BETWEEN ? AND ?", Metric.seven_day_range.first, Metric.seven_day_range.last).distinct }
  scope :matched,                -> { unresolved.with_active_buy.with_active_sell }
  scope :complete,               -> { active.where(id: BuyOrder.done.select(:contract_id).distinct).where(id: SellOrder.done.select(:contract_id).distinct) }
  scope :incomplete,             -> { active.where.not(id: complete) }
  # scope :matched_and_complete,   -> { matched.complete }
  scope :since_july2017,         -> { where("id > 56100") } # in July 2017, we changed the market-maker and trendline algorithms; before then, the ROI on contracts is unreliable.
  scope :ema_cross_750_2500_min, -> { trendline.where(algorithm: 'ema_crossover_750_2500_minutes') }
  scope :non_ema_crossover,      -> { where.not(id: ema_cross_750_2500_min) }

  # unresolved == with_buy_without_sell + with_sell_without_buy + matched

  # validate :association_ids_must_match
  # validates_associated :orders

  # TODO: add validation to ensure that each contract only has one active buy_order and sell_order

  # NOTE: Each contract could have many buy orders and many sell orders but each contract should only
  #       have one *active* buy order and sell order. The active orders are retrieved with .buy_order
  #       and .sell_order. The inactive orders are retained to track the contract's history. The active
  #       orders are the ones used to calculate the contract's ROI so whenever an order is activated
  #       or deactivated, the contract's ROI should be recalculated.

  # PROFIT = 0.10
  PROFIT_PERCENT = [0.002]
  MARGIN = 0.01
  # MAX_OPEN_ORDERS = 3
  # MAX_TIME_BETWEEN_ORDERS = 1.minute.ago.to_i

  def matched?
    buy_order.present? && sell_order.present?
  end

  def complete?
    buy_order.done? && sell_order.done?
  end

  def resolvable?
    matched? && complete?
  end

  def retired?
    status == 'retired'
  end

  def trendline?
    status == 'trendline'
  end

  def lacking_buy?
    sell_order.present? && sell_order.done? && buy_order.nil?
  end

  def lacking_sell?
    buy_order.present? && buy_order.done? && sell_order.nil?
  end

  def orders
    Order.where(contract_id: id)
  end

  def inactive_orders
    orders.where(status: Order::INACTIVE_STATUSES) # where.not includes orders with nil status in addition to other inactive statuses
  end

  def buy_order
    buy_orders.find_by(status: Order::ACTIVE_STATUSES)
  end

  def sell_order
    sell_orders.find_by(status: Order::ACTIVE_STATUSES)
  end

  def self.resolve_open
    # liquidate_old_contracts
    # populate_empty_contracts
    match_open_buys
    match_open_sells
  end

  def self.liquidate_old_contracts
    old_contract = liquidate.sample
    return if old_contract.nil?

    optional_params = { post_only: true }
    if old_contract.lacking_buy?
      current_bid = GDAX::MarketData.current_bid.round(2)
      Order.submit_order('buy', current_bid, Order::ORDER_SIZE, optional_params, old_contract.id, 'market-maker', nil)
    elsif old_contract.lacking_sell?
      current_ask = GDAX::MarketData.current_ask.round(2)
      Order.submit_order('sell', current_ask, Order::ORDER_SIZE, optional_params, old_contract.id, 'market-maker', nil)
    end
  end

  def self.populate_empty_contracts
    open_contracts = without_active_order.where.not(id: liquidate)
    if open_contracts.any?
      # current_bid = GDAX::MarketData.current_bid
      # return missing_price('bid') if current_bid == 0.0

      contract  = open_contracts.sample
      buy_price = Order.buy_price
      buy_order = Order.place_buy(buy_price, contract.id) # the contract has no buy-order and no sell-order so we start with a buy-order

      contract.update(gdax_buy_order_id: buy_order['id']) if buy_order
    end
  end

  def self.match_open_buys
    return if SellOrder.market_maker.where(status: ['open', 'pending']).count >= 1 # cap active buy orders at 3
    open_contract = market_maker.with_buy_without_sell.where.not(id: liquidate).includes(:buy_orders).order("orders.requested_price").first # finds contracts with lowest active buy price and without an active sell
    # open_contract = with_buy_without_sell.includes(:buy_orders).sample
    if open_contract
      return if open_contract.buy_order.status == 'pending' # if the buy order is pending, it may not have a price yet

      sell_price = calculate_sell_price(open_contract.buy_order).round(2)
      sell_order = Order.place_sell(sell_price, open_contract.id)

      open_contract.update(gdax_sell_order_id: sell_order['id']) if sell_order
    end
  end

  def self.match_open_sells
    return if BuyOrder.market_maker.where(status: ['open', 'pending']).count >= 1 # cap active sell orders at 3
    open_contract = market_maker.with_sell_without_buy.where.not(id: liquidate).includes(:sell_orders).order("orders.requested_price desc").first # finds contracts with highest active sell price and without an active buy
    # open_contract = with_sell_without_buy.includes(:sell_orders).sample
    if open_contract
      return if open_contract.sell_order.status == 'pending' # if the sell order is pending, it may not have a price yet

      buy_price = calculate_buy_price(open_contract.sell_order).round(2)
      buy_order = Order.place_buy(buy_price, open_contract.id)

      open_contract.update(gdax_buy_order_id: buy_order['id']) if buy_order
    end
  end

  def self.add_new_contract
    if unresolved.order(:created_at).last.created_at < 5.hours.ago
      puts "There are #{unresolved.count} stale contracts. Adding a new one."
      place_new_buy_order
    end
  end

  def self.place_new_buy_order # move to Order class?
    # a new BUY order gets executed when the USD account has enough funds to buy the selected amount
    # return if buys_backlog? || !buy_order_gap?
    return if BuyOrder.where(status: ['pending', 'open']).where(contract_id: Contract.where.not(id: SellOrder.done.select(:contract_id).distinct)).count > 0

    my_buy_price = Order.buy_price
    return missing_price('buy') if my_buy_price == 0.0
    new_order = Order.place_buy(my_buy_price)

    if new_order
      puts "placed new buy: #{new_order['id']} for $#{my_buy_price}"
      order = Order.find_by_gdax_id(new_order['id'])
      order.contract.update(gdax_buy_order_id: new_order['id'])
    end
  end

  # def self.logarithmic_buy
  #   # how many buy units are available? (up to 10)
  #   # if 10 units, then check current buy orders
  #   # if less than 10 units, then check current buy orders
  #   # if highest open buy order (without matching sell order) is more than x % lower than current bid,
  #   #   delete all open buy orders (without matching sell orders) and place 3 new buy order closer to current bid.
  #   #   then, successive loops will place new buy orders on the lower end
  #   # if highest open buy order is within range of current bid, then place new buy order on lower end of open buy orders.
  #   #   for example, if there are already 6 open buy orders (without matching sell orders), then add a 7th lower than the 6th
  #   buys_without_sells = BuyOrder.where(status: ['pending', 'open']).where(contract_id: Contract.where.not(id: SellOrder.done.select(:contract_id).distinct)).order(:requested_price)
  #   highest_buy_order  = buys_without_sells.last
  #   current_bid        = GDAX::MarketData.current_bid

  #   if current_bid && highest_buy_order && (current_bid > highest_buy_order.requested_price * 1.001)
  #     buys_without_sells.each {|o| Order.find_by(gdax_id: o.gdax_id).cancel_order }

  #     3.times do
  #       my_buy_price = Order.new_buy_price
  #       return missing_price('buy') if my_buy_price == 0.0
  #       new_order = Order.place_buy(my_buy_price)

  #       if new_order
  #         puts "placed new buy: #{new_order['id']} for $#{my_buy_price}"
  #         order = Order.find_by_gdax_id(new_order['id'])
  #         order.contract.update(gdax_buy_order_id: new_order['id'])
  #       end
  #     end
  #   else
  #     return if buys_without_sells.count > 10

  #     # place new buy order on lower end
  #     my_buy_price = Order.new_buy_price
  #     return missing_price('buy') if my_buy_price == 0.0
  #     new_order = Order.place_buy(my_buy_price)

  #     if new_order
  #       puts "placed new buy: #{new_order['id']} for $#{my_buy_price}"
  #       order = Order.find_by_gdax_id(new_order['id'])
  #       order.contract.update(gdax_buy_order_id: new_order['id'])
  #     end
  #   end
  # end

  def self.place_new_sell_order # move to Order class?
    # a new SELL order gets executed when the BTC account has enough funds to sell the selected amount
    # return if sells_backlog? || !sell_order_gap?
    return if SellOrder.where(status: ['pending', 'open']).where(contract_id: Contract.where.not(id: BuyOrder.done.select(:contract_id).distinct)).count > 0

    my_ask_price = Order.ask_price
    return missing_price('sell') if my_ask_price == 0.0
    new_order = Order.place_sell(my_ask_price)

    if new_order
      puts "placed new sell: #{new_order['id']} for $#{my_ask_price}"
      order = Order.find_by_gdax_id(new_order['id'])
      order.contract.update(gdax_sell_order_id: new_order['id'])
    end
  end

  # def self.logarithmic_sell
  #   sells_without_buys = SellOrder.where(status: ['pending', 'open']).where(contract_id: Contract.where.not(id: BuyOrder.done.select(:contract_id).distinct)).order(:requested_price)
  #   lowest_sell_order  = sells_without_buys.first
  #   current_ask        = GDAX::MarketData.current_ask

  #   if current_ask && lowest_sell_order && (current_ask < lowest_sell_order.requested_price * 0.999)
  #     sells_without_buys.each {|o| Order.find_by(gdax_id: o.gdax_id).cancel_order }

  #     3.times do
  #       my_sell_price = Order.new_ask_price
  #       return missing_price('sell') if my_sell_price == 0.0
  #       new_order = Order.place_sell(my_sell_price)

  #       if new_order
  #         puts "placed new sell: #{new_order['id']} for $#{my_sell_price}"
  #         order = Order.find_by_gdax_id(new_order['id'])
  #         order.contract.update(gdax_buy_order_id: new_order['id'])
  #       end
  #     end
  #   else
  #     return if sells_without_buys.count > 10

  #     # place new sell order on higher end
  #     my_sell_price = Order.new_ask_price
  #     return missing_price('sell') if my_sell_price == 0.0
  #     new_order = Order.place_sell(my_sell_price)

  #     if new_order
  #       puts "placed new sell: #{new_order['id']} for $#{my_sell_price}"
  #       order = Order.find_by_gdax_id(new_order['id'])
  #       order.contract.update(gdax_sell_order_id: new_order['id'])
  #     end
  #   end
  # end

  def self.buy_order_gap?
    bid         = GDAX::MarketData.current_bid
    highest_buy = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'buy' }.sort_by(&:price).last

    if highest_buy
      if bid
        (highest_buy.price * 1.0003) < bid
      else
        false
      end
    else
      true # if there are no current buys, return true to initiate a new buy
    end
  end

  def self.sell_order_gap?
    ask         = GDAX::MarketData.current_ask
    lowest_sell = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'sell' }.sort_by(&:price).first

    if lowest_sell
      if ask
        (lowest_sell.price * 0.9997) > ask
      else
        false
      end
    else
      true # if there are no current sells, return true to initiate a new sell
    end
  end

  def self.calculate_sell_price(open_buy)
    sell_minimum    = open_buy.requested_price * (1.0 + PROFIT_PERCENT.sample)
    sell_spread_min = Order.ask_price

    [sell_minimum, sell_spread_min].max
  end

  def self.calculate_buy_price(open_sell)
    buy_minimum    = open_sell.requested_price * (1.0 - PROFIT_PERCENT.sample)
    buy_spread_min = Order.buy_price

    [buy_minimum, buy_spread_min].min
  end

  def self.recent_buys?
    recent_buy_time = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'buy' }.sort_by(&:price).last.try(:created_at)
    # recent_buy_time = BuyOrder.unresolved.order(:price).last.try(:created_at)
    recent_buy_time ? (recent_buy_time > 1.minute.ago) : false
  end

  def self.recent_sells?
    recent_sell_time = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'sell' }.sort_by(&:price).last.try(:created_at)
    # recent_sell_time = SellOrder.unresolved.order(:price).first.try(:created_at)
    recent_sell_time ? (recent_sell_time > 1.minute.ago) : false
  end

  def self.buys_backlog?
    Contract.without_active_buy.count > 10
  end

  def self.sells_backlog?
    Contract.without_active_sell.count > 10
  end

  def self.update_status
    mark_as_done
    # mark_as_liquidate
  end

  def self.mark_as_done
    contract = resolvable.sample # for now, we are only checking the status of a random contract since we don't know which contracts will complete first
    if contract
      contract.mark_done
      contract.orders.unresolved.each {|o| o.cancel_order } # cancel any open orders (ex. stop orders) on the resolved contract
    end
  end

  def self.mark_as_liquidate
    contract = liquidatable.sample

    if contract
      puts "Updating status of #{contract.strategy_type} contract #{contract.id} from #{contract.status} to liquidate"
      contract.update(status: 'liquidate')
    end
  end

  def mark_done
    puts "Updating status of #{self.strategy_type} contract #{self.id} from #{self.status} to done"

    update(
      status: 'done',
      roi: calculate_roi,
      completion_date: Time.now,
      gdax_buy_order_id: buy_orders.done.first.gdax_id,
      gdax_sell_order_id: sell_orders.done.first.gdax_id
    )
  end

  def calculate_roi
    if sell_order.executed_value.nil?
      response = Order.check_status(sell_order.gdax_id)
      sell_order.update(gdax_status: response.status,
                        gdax_executed_value: response.executed_value,
                        gdax_filled_size: response.filled_size,
                        gdax_filled_fees: response.fill_fees,
                        status: response.status,
                        requested_price: response.price,
                        filled_price: Order.calculate_filled_price(response),
                        executed_value: response.executed_value,
                        quantity: response.filled_size,
                        fees: response.fill_fees)
    elsif buy_order.executed_value.nil?
      response = Order.check_status(buy_order.gdax_id)
      buy_order.update(gdax_status: response.status,
                       gdax_executed_value: response.executed_value,
                       gdax_filled_size: response.filled_size,
                       gdax_filled_fees: response.fill_fees,
                       status: response.status,
                       requested_price: response.price,
                       filled_price: Order.calculate_filled_price(response),
                       executed_value: response.executed_value,
                       quantity: response.filled_size,
                       fees: response.fill_fees)
    end

    calculated_roi = nil
    while calculated_roi.nil?
      profit = sell_order.executed_value - sell_order.fees
      cost   = buy_order.executed_value + buy_order.fees

      if profit == 0.0 || cost == 0.0
        Rails.logger.warn "ERROR: ROI can't be accurately calculated for contract #{self.id}: profit: #{profit}, cost: #{cost}"
        next
      end

      calculated_roi = profit - cost
    end

    calculated_roi
  end

  def self.missing_price(type)
    puts "GDAX orderbook returned a #{type} price of $0... It could be the result of a rate limit error."
    "GDAX orderbook returned a #{type} price of $0... It could be the result of a rate limit error."
  end

  #=================================================
    private
  #=================================================

end