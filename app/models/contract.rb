class Contract < ActiveRecord::Base

  has_one :buy_order, class_name: 'BuyOrder', foreign_key: 'contract_id'
  has_one :sell_order, class_name: 'SellOrder', foreign_key: 'contract_id'

  scope :with_buy_order,        -> { where(id: BuyOrder.select(:contract_id).distinct) }
  scope :with_sell_order,       -> { where(id: SellOrder.select(:contract_id).distinct) }
  scope :without_buy_order,     -> { where.not(id: BuyOrder.select(:contract_id).distinct) }
  scope :without_sell_order,    -> { where.not(id: SellOrder.select(:contract_id).distinct) }
  scope :with_buy_without_sell, -> { with_buy_order.without_sell_order }
  scope :with_sell_without_buy, -> { with_sell_order.without_buy_order }

  PROFIT = 0.10
  MARGIN = 0.01

  def self.resolve_open
    match_open_buys
    match_open_sells
  end

  def self.match_open_buys
    with_buy_without_sell.each do |contract|
      min_sell_price = contract.buy_order.price + PROFIT
      sell_price     = [Market.current_ask, min_sell_price].max.round(7)
      sell_order     = Order.place_sell(sell_price)

      if sell_order[:response_status] == 200
        contract.update(gdax_sell_order_id: sell_order[:id])
        new_order = Order.find_by_gdax_id(sell_order[:id])
        contract.sell_order = new_order
      else
        puts "SELL NOT COMPLETED: #{sell_order.inspect}\n\n"
      end
    end
  end

  def self.match_open_sells
    with_sell_without_buy.each do |contract|
      max_buy_price = contract.sell_order.price - PROFIT
      buy_price     = [Market.current_bid, max_buy_price].min.round(7)
      buy_order     = Order.place_buy(buy_price)

      if buy_order[:response_status] == 200
        contract.update(gdax_buy_order_id: buy_order[:id])
        new_order = Order.find_by_gdax_id(buy_order[:id])
        contract.buy_order = new_order
      else
        puts "BUY NOT COMPLETED: #{buy_order.inspect}"
      end
    end
  end

  def self.place_new_buy_order
    # a new BUY order gets executed when the USD account has enough funds to buy the selected amount
    new_order = Order.place_buy(my_buy_price)

    if new_order[:response_status] == 200
      order    = Order.find_by_gdax_id(new_order[:id])
      contract = Contract.create() # order.create_contract() doesn't correctly associate objects
      contract.update(gdax_buy_order_id: new_order[:id])
      contract.buy_order = order
    else
      # check if order was created on GDAX
      puts "BUY ORDER FAILED: #{new_order[:response_status]}"
    end
  end

  def self.place_new_sell_order(id, price)
    # a new SELL order gets executed when the BTC account has enough funds to sell the selected amount
    new_order = Order.place_sell(my_ask_price)

    if new_order[:response_status] == 200
      order    = Order.find_by_gdax_id(new_order[:id])
      contract = Contract.create() # order.create_contract() doesn't correctly associate objects
      contract.update(gdax_sell_order_id: new_order[:id])
      contract.sell_order = order
    else
      # check if order was created on GDAX
      puts "SELL ORDER FAILED: #{new_order[:response_status]}"
    end
  end

  def self.my_buy_price # move this into Order class?
    (Market.current_bid - MARGIN).round(7).to_s
  end

  def self.my_ask_price # move this into Order class?
    (Market.current_ask + MARGIN).round(7).to_s
  end

end