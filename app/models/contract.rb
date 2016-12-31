class Contract < ActiveRecord::Base

  has_many :buy_orders, class_name: 'BuyOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception
  has_many :sell_orders, class_name: 'SellOrder', foreign_key: 'contract_id', dependent: :restrict_with_exception

  # NOTE: consider querying contracts based on presence of gdax_order_ids
  scope :with_buy_orders,       -> { where(id: BuyOrder.select(:contract_id).distinct) }
  scope :with_sell_orders,      -> { where(id: SellOrder.select(:contract_id).distinct) }
  scope :with_active_buy,       -> { joins(:buy_orders).where(orders: {status: Order::ACTIVE_STATUSES}) }
  scope :with_active_sell,      -> { joins(:sell_orders).where(orders: {status: Order::ACTIVE_STATUSES}) }
  scope :without_buy_order,     -> { joins(:buy_orders).where(orders: {contract_id: nil}) }
  scope :without_sell_order,    -> { joins(:sell_orders).where(orders: {contract_id: nil}) }
  scope :without_active_buy,    -> { joins(:buy_orders).where.not(orders: {status: Order::ACTIVE_STATUSES}) }
  scope :without_active_sell,   -> { joins(:sell_orders).where.not(orders: {status: Order::ACTIVE_STATUSES}) }
  scope :with_buy_without_sell, -> { with_active_buy.without_active_sell }
  scope :with_sell_without_buy, -> { with_active_sell.without_active_buy }
  scope :resolved,              -> { where(status: ['done']) }
  scope :unresolved,            -> { where.not(id: resolved) }
  scope :resolvable,            -> { unresolved.merge(matched_and_complete) }
  scope :matched,               -> { find_by_sql(
                                       "SELECT \"contracts\".* FROM \"contracts\"
                                        LEFT JOIN \"orders\" sell_orders
                                          ON \"sell_orders\".\"contract_id\" = \"contracts\".\"id\"
                                          AND \"sell_orders\".\"type\" = 'SellOrder'
                                        LEFT JOIN \"orders\" buy_orders
                                          ON \"buy_orders\".\"contract_id\" = \"contracts\".\"id\"
                                          AND \"buy_orders\".\"type\" = 'BuyOrder'
                                        WHERE \"sell_orders\".\"id\" IS NOT NULL
                                          AND \"buy_orders\".\"id\" IS NOT NULL"
                                      ) }
  scope :unmatched,             -> { where.not(id: matched) }
  scope :complete,              -> { find_by_sql(
                                       "SELECT \"contracts\".* FROM \"contracts\"
                                        LEFT JOIN \"orders\" sell_orders
                                          ON \"sell_orders\".\"contract_id\" = \"contracts\".\"id\"
                                          AND \"sell_orders\".\"type\" = 'SellOrder'
                                        LEFT JOIN \"orders\" buy_orders
                                          ON \"buy_orders\".\"contract_id\" = \"contracts\".\"id\"
                                          AND \"buy_orders\".\"type\" = 'BuyOrder'
                                        WHERE \"sell_orders\".\"status\" = 'done'
                                          AND \"buy_orders\".\"status\" = 'done'"
                                      ) }
  scope :incomplete,            -> { where.not(id: complete) }
  scope :matched_and_complete,  -> { find_by_sql(
                                       "SELECT \"contracts\".* FROM \"contracts\"
                                        LEFT JOIN \"orders\" sell_orders
                                          ON \"sell_orders\".\"contract_id\" = \"contracts\".\"id\"
                                          AND \"sell_orders\".\"type\" = 'SellOrder'
                                        LEFT JOIN \"orders\" buy_orders
                                          ON \"buy_orders\".\"contract_id\" = \"contracts\".\"id\"
                                          AND \"buy_orders\".\"type\" = 'BuyOrder'
                                        WHERE \"sell_orders\".\"id\" IS NOT NULL
                                          AND \"buy_orders\".\"id\" IS NOT NULL
                                          AND \"sell_orders\".\"status\" = 'done'
                                          AND \"buy_orders\".\"status\" = 'done'"
                                      ) }

  # validate :association_ids_must_match
  # validates_associated :orders

  # TODO: add validation to ensure that each contract only has one active buy_order and sell_order

  # NOTE: Each contract could have many buy orders and many sell orders but each contract should only
  #       have one *active* buy order and sell order. The active orders are retrieved with .buy_order
  #       and .sell_order. The inactive orders are retained to track the contract's history. The active
  #       orders are the ones used to calculate the contract's ROI so whenever an order is activated
  #       or deactivated, the contract's ROI should be recalculated.

  # PROFIT = 0.10
  PROFIT_PERCENT = 0.0002
  MARGIN = 0.01
  MAX_OPEN_ORDERS = 3

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
    match_open_buys
    match_open_sells
  end

  def self.match_open_buys
    open_contracts = with_buy_without_sell # finds contracts with ACTIVE buy and without ACTIVE sell
    if open_contracts.any?
      current_ask = GDAX::MarketData.current_ask
      return missing_price('ask') if current_ask == 0.0

      open_contracts.each do |contract|
        next if contract.buy_order.status == 'pending' # if the buy order is pending, it may not have a price yet
        min_sell_price = contract.buy_order.price * (1.0 + PROFIT_PERCENT)
        sell_price     = [current_ask, min_sell_price].compact.max.round(2)
        sell_order     = Order.place_sell(sell_price)

        if sell_order
          contract.update(gdax_sell_order_id: sell_order['id'])
          new_order = Order.find_by_gdax_id(sell_order['id'])
          contract.sell_orders << new_order
        end
      end
    end
  end

  def self.match_open_sells
    open_contracts = with_sell_without_buy # finds contracts with ACTIVE sell and without ACTIVE buy
    if open_contracts.any?
      current_bid = GDAX::MarketData.current_bid
      return missing_price('bid') if current_bid == 0.0

      open_contracts.each do |contract|
        next if contract.sell_order.status == 'pending' # if the sell order is pending, it may not have a price yet
        max_buy_price = contract.sell_order.price * (1.0 - PROFIT_PERCENT)
        buy_price     = [current_bid, max_buy_price].min.round(2)
        buy_order     = Order.place_buy(buy_price)

        if buy_order
          contract.update(gdax_buy_order_id: buy_order['id'])
          new_order = Order.find_by_gdax_id(buy_order['id'])
          contract.buy_orders << new_order
        end
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
      contract.buy_orders << order
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
      contract.sell_orders << order
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

end