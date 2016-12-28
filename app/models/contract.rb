class Contract < ActiveRecord::Base

  has_one :buy_order, class_name: 'BuyOrder', foreign_key: 'contract_id'
  has_one :sell_order, class_name: 'SellOrder', foreign_key: 'contract_id'

  scope :with_buy_order,        -> { where(id: BuyOrder.select(:contract_id).distinct) }
  scope :with_sell_order,       -> { where(id: SellOrder.select(:contract_id).distinct) }
  scope :without_buy_order,     -> { where.not(id: BuyOrder.select(:contract_id).distinct) }
  scope :without_sell_order,    -> { where.not(id: SellOrder.select(:contract_id).distinct) }
  scope :with_buy_without_sell, -> { with_buy_order.without_sell_order }
  scope :with_sell_without_buy, -> { with_sell_order.without_buy_order }
  scope :resolved,              -> { where(status: ['done']) }
  scope :unresolved,            -> { where.not(id: resolved) }

  # TODO: add validation to prevent orders with 'rejected' status (and other statuses?) from being associated with a contract

  # PROFIT = 0.10
  PROFIT_PERCENT = 0.0002
  MARGIN = 0.01
  MAX_OPEN_ORDERS = 3

  def self.resolve_open
    match_open_buys
    match_open_sells
  end

  def self.match_open_buys
    current_ask = Market.current_ask
    return missing_price('ask') if current_ask == 0.0

    with_buy_without_sell.each do |contract|
      min_sell_price = contract.buy_order.price * (1.0 + PROFIT_PERCENT)
      sell_price     = [current_ask, min_sell_price].compact.max.round(3)
      sell_order     = Order.place_sell(sell_price)

      if sell_order
        contract.update(gdax_sell_order_id: sell_order['id'])
        new_order = Order.find_by_gdax_id(sell_order['id'])
        contract.sell_order = new_order
      end
    end
  end

  def self.match_open_sells
    current_bid = Market.current_bid
    return missing_price('bid') if current_bid == 0.0

    with_sell_without_buy.each do |contract|
      max_buy_price = contract.sell_order.price * (1.0 - PROFIT_PERCENT)
      buy_price     = [current_bid, max_buy_price].min.round(3)
      buy_order     = Order.place_buy(buy_price)

      if buy_order
        contract.update(gdax_buy_order_id: buy_order['id'])
        new_order = Order.find_by_gdax_id(buy_order['id'])
        contract.buy_order = new_order
      end
    end
  end

  def self.place_new_buy_order
    # a new BUY order gets executed when the USD account has enough funds to buy the selected amount
    return if BuyOrder.unresolved.count > MAX_OPEN_ORDERS
    return missing_price('buy') if my_buy_price == 0.0
    new_order = Order.place_buy(my_buy_price)

    if new_order
      order    = Order.find_by_gdax_id(new_order['id'])
      contract = Contract.create() # order.create_contract() doesn't correctly associate objects
      contract.update(gdax_buy_order_id: new_order['id'])
      contract.buy_order = order
    end
  end

  def self.place_new_sell_order
    # a new SELL order gets executed when the BTC account has enough funds to sell the selected amount
    return if SellOrder.unresolved.count > MAX_OPEN_ORDERS
    return missing_price('sell') if my_ask_price == 0.0
    new_order = Order.place_sell(my_ask_price)

    if new_order
      order    = Order.find_by_gdax_id(new_order['id'])
      contract = Contract.create() # order.create_contract() doesn't correctly associate objects
      contract.update(gdax_sell_order_id: new_order['id'])
      contract.sell_order = order
    end
  end

  def self.my_buy_price # move this into Order class?
    current_bid = Market.current_bid
    if current_bid == 0.0
      return current_bid
    else
      (current_bid - MARGIN).round(3)
    end
  end

  def self.my_ask_price # move this into Order class?
    current_ask = Market.current_ask
    if current_ask == 0.0
      return current_ask
    else
      (current_ask + MARGIN).round(3)
    end
  end

  def self.update_status
    contract = unresolved.sample # for now, we are only checking the status of a random contract since we don't know which contracts will complete first
    contract.update_status unless contract.nil?
  end

  def update_status
    if completed?
      puts "Updating status of contract #{self.id} from #{self.status} to done"
      update(status: 'done')
    end
  end

  def completed?
    orders.all? {|o| o.present? && o.closed? }
  end

  def orders
    [ buy_order, sell_order ]
  end

  def self.missing_price(type)
    puts "GDAX orderbook returned a #{type} price of $0... It could be the result of a rate limit error."
    "GDAX orderbook returned a #{type} price of $0... It could be the result of a rate limit error."
  end

end