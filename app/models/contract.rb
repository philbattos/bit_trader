class Contract < ActiveRecord::Base
  before_create { self.status = "new" unless self.status }

  has_many :buy_orders, class_name: 'BuyOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception
  has_many :sell_orders, class_name: 'SellOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception

  # NOTE: consider querying contracts based on presence of gdax_order_ids
  scope :retired,               -> { where(status: 'retired') }
  scope :liquidate,             -> { where(status: 'liquidate') }
  scope :trendline,             -> { where(strategy_type: 'trendline') }
  scope :market_maker,          -> { where(strategy_type: 'market-maker') }
  scope :adjust_balance,        -> { where(strategy_type: 'adjust-balance') }
  scope :active,                -> { where.not(id: retired).where.not(id: adjust_balance) }
  scope :with_buy_orders,       -> { active.where(id: BuyOrder.select(:contract_id).distinct) }
  scope :with_sell_orders,      -> { active.where(id: SellOrder.select(:contract_id).distinct) }
  scope :without_buy_orders,    -> { active.where.not(id: with_buy_orders) }
  scope :without_sell_orders,   -> { active.where.not(id: with_sell_orders) }
  scope :with_active_buy,       -> { active.where(id: BuyOrder.active.select(:contract_id).distinct) }
  scope :with_active_sell,      -> { active.where(id: SellOrder.active.select(:contract_id).distinct) }
  scope :without_active_buy,    -> { active.where.not(id: with_active_buy) }
  scope :without_active_sell,   -> { active.where.not(id: with_active_sell) }
  scope :with_buy_without_sell, -> { with_active_buy.without_active_sell }
  scope :with_sell_without_buy, -> { with_active_sell.without_active_buy }
  scope :without_active_order,  -> { without_active_buy.without_active_sell } # this happens when an order is created and then canceled before it can be matched with another order
  scope :resolved,              -> { active.where(status: ['done']) }
  scope :unresolved,            -> { active.where.not(id: resolved) }
  scope :resolvable,            -> { matched.complete }
  scope :liquidatable,          -> { unresolved.where.not(id: liquidate).where("created_at < ?", 1.day.ago).where(id: Order.liquidatable.select(:contract_id)).distinct }
  # scope :liquidatable_sell,     -> { unresolved.where.not(id: liquidate).joins(:buy_orders).where("contracts.created_at < ?", 1.day.ago).where("orders.status = 'done' AND orders.requested_price NOT BETWEEN ? AND ?", Metric.seven_day_range.first, Metric.seven_day_range.last).distinct }
  # scope :liquidatable_buy,      -> { unresolved.where.not(id: liquidate).joins(:sell_orders).where("contracts.created_at < ?", 1.day.ago).where("orders.status = 'done' AND orders.requested_price NOT BETWEEN ? AND ?", Metric.seven_day_range.first, Metric.seven_day_range.last).distinct }
  # scope :liquidatable_all,      -> { unresolved.where.not(id: liquidate).joins(:buy_orders, :sell_orders).where("contracts.created_at < ?", 1.day.ago).where.not("orders.status = 'done' AND orders.requested_price BETWEEN ? AND ?", Metric.seven_day_range.first, Metric.seven_day_range.last).distinct }
  scope :matched,               -> { unresolved.with_active_buy.with_active_sell }
  scope :complete,              -> { active.where(id: BuyOrder.done.select(:contract_id).distinct).where(id: SellOrder.done.select(:contract_id).distinct) }
  scope :incomplete,            -> { active.where.not(id: complete) }
  # scope :matched_and_complete,  -> { matched.complete }

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
  PROFIT_PERCENT = [0.0002, 0.0003, 0.0004, 0.0005, 0.0006, 0.0007, 0.0008, 0.0009, 0.0010, 0.0015, 0.0020]
  MARGIN = 0.01
  # MAX_OPEN_ORDERS = 3
  # MAX_TIME_BETWEEN_ORDERS = 1.minute.ago.to_i

  def matched?
    buy_order.present? && sell_order.present?
  end

  def complete?
    buy_order.done? && sell_order.done?
  end

  def retired?
    status == 'retired'
  end

  def trendline?
    status == 'trendline'
  end

  def lacking_buy?
    sell_order && sell_order.done? && buy_order.nil?
  end

  def lacking_sell?
    buy_order && buy_order.done? && sell_order.nil?
  end

  def orders
    Order.where(contract_id: id)
  end

  def inactive_orders
    orders.where(status: Order::INACTIVE_STATUSES) # where.not includes orders with nil status in addition to other inactive statuses
  end

  def buy_order
    buy_orders.find_by(status: Order::ACTIVE_STATUSES) # NOTE: there should be only one active buy order per contract
  end

  def sell_order
    sell_orders.find_by(status: Order::ACTIVE_STATUSES) # NOTE: there should be only one active sell order per contract
  end

  def self.resolve_open
    liquidate_old_contracts
    populate_empty_contracts
    match_open_buys
    match_open_sells
  end

  def self.liquidate_old_contracts
    old_contract = liquidate.sample
    return if old_contract.nil?

    if old_contract.lacking_buy?
      current_bid = GDAX::MarketData.current_bid.round(2)
      response = Order.submit('buy', current_bid, old_contract.id)
    elsif old_contract.lacking_sell?
      current_ask = GDAX::MarketData.current_ask.round(2)
      Order.submit('sell', current_ask, old_contract.id)
    end
  end

  def self.populate_empty_contracts
    open_contracts = without_active_order.where.not(id: liquidate)
    if open_contracts.any?
      current_bid = GDAX::MarketData.current_bid
      return missing_price('bid') if current_bid == 0.0

      contract  = open_contracts.sample
      buy_price = current_bid.round(2)
      # the contract has no buy-order and no sell-order so we start with a buy-order
      buy_order = Order.place_buy(buy_price, contract.id)

      contract.update(gdax_buy_order_id: buy_order['id']) if buy_order
    end
  end

  def self.match_open_buys
    return if SellOrder.where(status: ['open', 'pending']).count > 10
    open_contract = with_buy_without_sell.where.not(id: liquidate).includes(:buy_orders).order("orders.requested_price").first # finds contracts with lowest active buy price and without an active sell
    # open_contract = with_buy_without_sell.includes(:buy_orders).sample
    if open_contract
      current_ask = GDAX::MarketData.current_ask
      return missing_price('ask') if current_ask == 0.0

      return if open_contract.buy_order.status == 'pending' # if the buy order is pending, it may not have a price yet

      min_sell_price = calculate_sell_price(open_contract.buy_order)
      sell_price     = [current_ask, min_sell_price].compact.max.round(2)
      sell_order     = Order.place_sell(sell_price, open_contract.id)

      open_contract.update(gdax_sell_order_id: sell_order['id']) if sell_order
    end
  end

  def self.match_open_sells
    return if BuyOrder.where(status: ['open', 'pending']).count > 10
    open_contract = with_sell_without_buy.where.not(id: liquidate).includes(:sell_orders).order("orders.requested_price desc").first # finds contracts with highest active sell price and without an active buy
    # open_contract = with_sell_without_buy.includes(:sell_orders).sample
    if open_contract
      current_bid = GDAX::MarketData.current_bid
      return missing_price('bid') if current_bid == 0.0

      return if open_contract.sell_order.status == 'pending' # if the sell order is pending, it may not have a price yet

      max_buy_price = calculate_buy_price(open_contract.sell_order)
      buy_price     = [current_bid, max_buy_price].compact.min.round(2)
      buy_order     = Order.place_buy(buy_price, open_contract.id)

      open_contract.update(gdax_buy_order_id: buy_order['id']) if buy_order
    end
  end

  def self.place_new_buy_order # move to Order class?
    # a new BUY order gets executed when the USD account has enough funds to buy the selected amount
    # return if buys_backlog? || recent_buys?
    return unless buy_order_gap? && !buys_backlog?

    my_buy_price = Order.buy_price
    return missing_price('buy') if my_buy_price == 0.0
    new_order = Order.place_buy(my_buy_price)

    if new_order
      puts "placed new buy: #{new_order['id']}"
      order = Order.find_by_gdax_id(new_order['id'])
      order.contract.update(gdax_buy_order_id: new_order['id'])
    end
  end

  def self.place_new_sell_order # move to Order class?
    # a new SELL order gets executed when the BTC account has enough funds to sell the selected amount
    # return if sells_backlog? || recent_sells?
    return unless sell_order_gap? && !sells_backlog?

    my_ask_price = Order.ask_price
    return missing_price('sell') if my_ask_price == 0.0
    new_order = Order.place_sell(my_ask_price)

    if new_order
      puts "placed new sell: #{new_order['id']}"
      order = Order.find_by_gdax_id(new_order['id'])
      order.contract.update(gdax_sell_order_id: new_order['id'])
    end
  end

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
    open_buy.requested_price * (1.0 + PROFIT_PERCENT.sample)
    # if open_buy.updated_at > 6.hours.ago
    #   open_buy.requested_price * (1.0 + PROFIT_PERCENT.sample)
    # else
    #   nil # setting the sell price to nil will force the bot to place a sell order at the current asking price
    # end
  end

  def self.calculate_buy_price(open_sell)
    open_sell.requested_price * (1.0 - PROFIT_PERCENT.sample)
    # if open_sell.updated_at > 6.hours.ago
    #   open_sell.requested_price * (1.0 - PROFIT_PERCENT.sample)
    # else
    #   nil # setting the sell price to nil will force the bot to place a sell order at the current asking price
    # end
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
    # open_buy_orders = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'buy' }
    # open_buy_orders.count > 5
    # unresolved.with_active_buy.count > 5
    # open_buy_orders = unresolved.where(id: BuyOrder.where(status: ['open', 'pending']).select(:contract_id).distinct)
    # open_buy_orders.count > 5
  end

  def self.sells_backlog?
    Contract.without_active_sell.count > 10
    # open_sell_orders = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'sell' }
    # open_sell_orders.count > 5
    # unresolved.with_active_sell.count > 5
    # open_sell_orders = unresolved.where(id: SellOrder.where(status: ['open', 'pending']).select(:contract_id).distinct)
    # open_sell_orders.count > 5
  end

  # def self.seven_day_range
  #   metric  = Metric.order(:created_at).last
  #   return -2..-1 if metric.average_7_day.nil?

  #   floor   = metric.average_7_day * 0.95
  #   ceiling = metric.average_7_day * 1.05

  #   floor..ceiling
  # end

  def self.update_status
    mark_as_done
    mark_as_liquidate
  end

  def self.mark_as_done
    contract = resolvable.sample # for now, we are only checking the status of a random contract since we don't know which contracts will complete first
    contract.mark_done if contract
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
      completion_date: Time.now
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

    profit = sell_order.executed_value - sell_order.fees
    cost   = buy_order.executed_value + buy_order.fees

    profit - cost
  end

  def self.missing_price(type)
    puts "GDAX orderbook returned a #{type} price of $0... It could be the result of a rate limit error."
    "GDAX orderbook returned a #{type} price of $0... It could be the result of a rate limit error."
  end

  #=================================================
    private
  #=================================================

end