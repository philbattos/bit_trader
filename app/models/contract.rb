class Contract < ActiveRecord::Base
  before_create { self.status = "new" }

  has_many :buy_orders, class_name: 'BuyOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception
  has_many :sell_orders, class_name: 'SellOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception

  # NOTE: consider querying contracts based on presence of gdax_order_ids
  scope :with_buy_orders,       -> { where(id: BuyOrder.select(:contract_id).distinct) }
  scope :with_sell_orders,      -> { where(id: SellOrder.select(:contract_id).distinct) }
  scope :without_buy_orders,    -> { where.not(id: with_buy_orders) }
  scope :without_sell_orders,   -> { where.not(id: with_sell_orders) }
  scope :with_active_buy,       -> { where(id: BuyOrder.active.select(:contract_id).distinct) }
  scope :with_active_sell,      -> { where(id: SellOrder.active.select(:contract_id).distinct) }
  scope :without_active_buy,    -> { where.not(id: with_active_buy) }
  scope :without_active_sell,   -> { where.not(id: with_active_sell) }
  scope :with_buy_without_sell, -> { with_active_buy.without_active_sell }
  scope :with_sell_without_buy, -> { with_active_sell.without_active_buy }
  scope :without_active_order,  -> { without_active_buy.without_active_sell } # this happens when an order is created and then canceled before it can be matched with another order
  scope :resolved,              -> { where(status: ['done']) }
  scope :unresolved,            -> { where.not(id: resolved) }
  scope :resolvable,            -> { matched.complete }
  scope :matched,               -> { unresolved.with_active_buy.with_active_sell }
  scope :complete,              -> { where(id: BuyOrder.done.select(:contract_id).distinct).where(id: SellOrder.done.select(:contract_id).distinct) }
  scope :incomplete,            -> { where.not(id: complete) }
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
  PROFIT_PERCENT = 0.0003
  MARGIN = 0.01
  MAX_OPEN_ORDERS = 3
  # MAX_TIME_BETWEEN_ORDERS = 1.minute.ago.to_i

  def matched?
    buy_order.present? && sell_order.present?
  end

  def complete?
    buy_order.done? && sell_order.done?
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
    open_contract = with_buy_without_sell.includes(:buy_orders).order("orders.price").first # finds contracts with lowest active buy price and without an active sell
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
    open_contract = with_sell_without_buy.includes(:sell_orders).order("orders.price desc").first # finds contracts with highest active sell price and without an active buy
    if open_contract
      current_bid = GDAX::MarketData.current_bid
      return missing_price('bid') if current_bid == 0.0

      return if open_contract.sell_order.status == 'pending' # if the sell order is pending, it may not have a price yet

      max_buy_price = calculate_buy_price(open_contract.sell_order)
      buy_price     = [current_bid, max_buy_price].min.round(2)
      buy_order     = Order.place_buy(buy_price, open_contract.id)

      open_contract.update(gdax_buy_order_id: buy_order['id']) if buy_order
    end
  end

  def self.place_new_buy_order # move to Order class?
    # a new BUY order gets executed when the USD account has enough funds to buy the selected amount
    return if recent_buys?
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
    return if recent_sells?
    return missing_price('sell') if my_ask_price == 0.0
    new_order = Order.place_sell(my_ask_price)

    if new_order
      puts "placed new sell: #{new_order['id']}"
      order = Order.find_by_gdax_id(new_order['id'])
      order.contract.update(gdax_sell_order_id: new_order['id'])
    end
  end

  def self.calculate_sell_price(open_buy)
    if open_buy.updated_at < 10.hours.ago
      open_buy.price * (1.0 + PROFIT_PERCENT)
    else
      nil # setting the sell price to nil will force the bot to place a sell order at the current asking price
    end
  end

  def self.calculate_buy_price(open_sell)
    if open_sell.updated_at < 10.hours.ago
      open_sell.price * (1.0 - PROFIT_PERCENT)
    else
      nil # setting the sell price to nil will force the bot to place a sell order at the current asking price
    end
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
    open_buys = BuyOrder.unresolved.order(:created_at).last.try(:created_at)
    open_buys ? (open_buys > 1.minute.ago) : false
  end

  def self.recent_sells?
    open_sells = SellOrder.unresolved.order(:created_at).last.try(:created_at)
    open_sells ? (open_sells.to_i > 1.minute.ago.to_i) : false
  end

  def self.full_buys?
    BuyOrder.unresolved.count > MAX_OPEN_ORDERS
  end

  def self.full_sells?
    SellOrder.unresolved.count > MAX_OPEN_ORDERS
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