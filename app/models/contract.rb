class Contract < ActiveRecord::Base
  before_create { self.status = "new" }

  has_many :buy_orders, class_name: 'BuyOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception
  has_many :sell_orders, class_name: 'SellOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception

  # NOTE: consider querying contracts based on presence of gdax_order_ids
  scope :retired,               -> { where(status: 'retired') }
  scope :active,                -> { where.not(id: retired) }
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
  scope :resolved,              -> { active.where(status: ['done', 'retired']) }
  scope :unresolved,            -> { active.where.not(id: resolved) }
  scope :resolvable,            -> { matched.complete }
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
    populate_empty_contracts
    match_open_buys
    match_open_sells
  end

  def self.populate_empty_contracts
    open_contracts = without_active_order
    if open_contracts.any?
      current_bid = GDAX::MarketData.current_bid
      return missing_price('bid') if current_bid == 0.0

      contract  = open_contracts.sample
      buy_price = current_bid.round(2)
      buy_order = Order.place_buy(buy_price, contract.id)

      contract.update(gdax_buy_order_id: buy_order['id']) if buy_order
    end
  end

  def self.match_open_buys
    return if SellOrder.where(status: ['open', 'pending']).count > 5
    open_contract = with_buy_without_sell.includes(:buy_orders).order("orders.price").first # finds contracts with lowest active buy price and without an active sell
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
    return if BuyOrder.where(status: ['open', 'pending']).count > 5
    open_contract = with_sell_without_buy.includes(:sell_orders).order("orders.price desc").first # finds contracts with highest active sell price and without an active buy
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
    return unless buy_order_gap?
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
    return unless sell_order_gap?
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
    if bid && highest_buy
      (highest_buy.price * 1.0005) < bid
    end
  end

  def self.sell_order_gap?
    ask         = GDAX::MarketData.current_ask
    lowest_sell = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'sell' }.sort_by(&:price).first
    if ask && lowest_sell
      (lowest_sell.price * 0.9995) > ask
    end
  end

  def self.calculate_sell_price(open_buy)
    open_buy.price * (1.0 + PROFIT_PERCENT.sample)
    # if open_buy.updated_at > 6.hours.ago
    #   open_buy.price * (1.0 + PROFIT_PERCENT.sample)
    # else
    #   nil # setting the sell price to nil will force the bot to place a sell order at the current asking price
    # end
  end

  def self.calculate_buy_price(open_sell)
    open_sell.price * (1.0 - PROFIT_PERCENT.sample)
    # if open_sell.updated_at > 6.hours.ago
    #   open_sell.price * (1.0 - PROFIT_PERCENT.sample)
    # else
    #   nil # setting the sell price to nil will force the bot to place a sell order at the current asking price
    # end
  end

  def self.my_buy_price # move this into Order class?
    current_bid = GDAX::MarketData.current_bid
    if current_bid == 0.0
      return current_bid
    else
      (current_bid - MARGIN).round(2)
    end
  end

  def self.my_ask_price # move this into Order class?
    current_ask = GDAX::MarketData.current_ask
    if current_ask == 0.0
      return current_ask
    else
      (current_ask + MARGIN).round(2)
    end
  end

  def self.recent_buys?
    recent_buy_time = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'buy' }.sort_by(&:price).last.try(:created_at)
    # recent_buy_time = BuyOrder.unresolved.order(:price).last.try(:created_at)
    recent_buy_time ? (recent_buy_time > 2.minutes.ago) : false
  end

  def self.recent_sells?
    recent_sell_time = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'sell' }.sort_by(&:price).last.try(:created_at)
    # recent_sell_time = SellOrder.unresolved.order(:price).first.try(:created_at)
    recent_sell_time ? (recent_sell_time > 2.minutes.ago) : false
  end

  def self.buys_backlog?
    Contract.without_active_buy.count > 5
    # open_buy_orders = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'buy' }
    # open_buy_orders.count > 5
    # unresolved.with_active_buy.count > 5
    # open_buy_orders = unresolved.where(id: BuyOrder.where(status: ['open', 'pending']).select(:contract_id).distinct)
    # open_buy_orders.count > 5
  end

  def self.sells_backlog?
    Contract.without_active_sell.count > 5
    # open_sell_orders = GDAX::Connection.new.rest_client.orders(status: 'open').select {|o| o.side == 'sell' }
    # open_sell_orders.count > 5
    # unresolved.with_active_sell.count > 5
    # open_sell_orders = unresolved.where(id: SellOrder.where(status: ['open', 'pending']).select(:contract_id).distinct)
    # open_sell_orders.count > 5
  end

  def self.update_status
    contract = resolvable.sample # for now, we are only checking the status of a random contract since we don't know which contracts will complete first
    contract.mark_as_done if contract
  end

  def mark_as_done
    puts "Updating status of contract #{self.id} from #{self.status} to done"

    update(
      status: 'done',
      roi: calculate_roi,
      completion_date: Time.now
    )
  end

  def calculate_roi
    profit = (sell_order.price * sell_order.quantity) - sell_order.fees
    cost   = (buy_order.price * buy_order.quantity) + buy_order.fees

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