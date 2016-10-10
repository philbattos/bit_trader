class Contract < ActiveRecord::Base

  has_one :buy_order, class_name: 'BuyOrder', foreign_key: 'contract_id'
  has_one :sell_order, class_name: 'SellOrder', foreign_key: 'contract_id'

  scope :with_buy_order,     -> { where(id: BuyOrder.select(:contract_id).uniq) }
  scope :with_sell_order,    -> { where(id: SellOrder.select(:contract_id).uniq) }
  scope :without_buy_order,  -> { where.not(id: BuyOrder.select(:contract_id).uniq) }
  scope :without_sell_order, -> { where.not(id: SellOrder.select(:contract_id).uniq) }

  BID_DECREMENT = 0.01
  PROFIT        = 0.10
  # ASK_INCREMENT = 0.10

  def self.resolve_open
    without_sell_order.each do |contract|
      current_ask    = Market.fetch_ticker['ask'].to_f.round(7)
      min_sell_price = contract.buy_order.amount + PROFIT
      sell_price     = [current_ask, min_sell_price].max
      sell_order     = Order.place_sell(sell_price.to_s)
      # puts "SELL ORDER: #{sell_order.inspect}"

      if sell_order['response-status'] == 200
        # contract.update(sell_order_id: sell_order['id'])
        new_order = Order.find_by_gdax_id(sell_order['id'])
        contract.sell_order = new_order
      else
        puts "SELL NOT COMPLETED: #{sell_order.inspect}\n\n"
      end
    end

    without_buy_order.each do |contract|
      current_bid   = Market.fetch_ticker['bid'].to_f.round(7)
      max_buy_price = contract.sell_order.amount - PROFIT
      buy_price     = [current_bid, max_buy_price].min
      buy_order     = Order.place_buy(buy_price.to_s)

      if buy_order['response-status'] == 200
        # contract.update(buy_order_id: buy_order['id'])
        new_order = Order.find_by_gdax_id(buy_order['id'])
        contract.buy_order = new_order
      else
        puts "BUY NOT COMPLETED: #{buy_order.inspect}"
      end
    end
  end

end