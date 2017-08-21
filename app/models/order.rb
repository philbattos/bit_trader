class Order < ActiveRecord::Base

  #-------------------------------------------------
  #    associations
  #-------------------------------------------------
  belongs_to :contract

  #-------------------------------------------------
  #    scopes
  #-------------------------------------------------
  scope :trendline,      -> { where(strategy_type: 'trendline') }
  scope :market_maker,   -> { where(strategy_type: 'market-maker') }
  scope :adjust_balance, -> { where(strategy_type: 'adjust-balance') }
  scope :resolved,       -> { where(status: CLOSED_STATUSES) }
  scope :unresolved,     -> { where.not(id: resolved) }
  scope :active,         -> { where(status: ACTIVE_STATUSES) }
  # scope :inactive,       -> { where(updated_at: Date.parse('october 8 2016')..2.hours.ago) }
  scope :purchased,      -> { where(status: PURCHASED_STATUSES) }
  scope :canceled,       -> { where(status: 'not-found') }
  scope :done,           -> { where(status: 'done') }
  scope :retired,        -> { where(status: 'retired') }
  scope :stop_orders,    -> { where.not(stop_type: nil) }
  scope :liquidatable,   -> { done.where.not(requested_price: Metric.three_day_range) }
  # NOTE: unfilled orders that are canceled are given a status of 'done' and deleted from GDAX
  #       partially filled orders that are canceled are given a status of 'done' and a done_reason of 'canceled'

  #-------------------------------------------------
  #    validations
  #-------------------------------------------------
  validates :contract,      presence: true # all orders should be associated with a contract
  validates :strategy_type, presence: true

  #-------------------------------------------------
  #    constants
  #-------------------------------------------------
  CLOSED_STATUSES    = %w[ done rejected not-found retired ]
  PURCHASED_STATUSES = %w[ done open ]
  ACTIVE_STATUSES    = %w[ done open pending active ]
  INACTIVE_STATUSES  = %w[ rejected not-found ] << nil # nil should be considered an "inactive" status
  ORDER_SIZE         = 0.01
  MARGIN             = 0.01
  TRADING_UNITS      = 36
  SPREAD_PERCENT     = 0.01
  PROFIT_PERCENT     = 0.002
  INCREMENTS         = [0.0002, 0.0003, 0.0005, 0.0008, 0.0013, 0.0021, 0.0034, 0.0055, 0.0089, 0.0123, 0.0212, 0.0335, 0.0547, 0.0882, 0.1429] # fibonacci increments

  # TODO: add validation for gdax_id (every order should have one)
  # TODO: add validation for status (every order should have one; can cause confusion if order has status of nil)
  # TODO: currently, we can create an order without an associated contract but it would be better if
  #       every order had an associated contract. find a way to build orders and contracts together
  #       and then add validations to prevent orphaned orders and contracts

  # NOTE: GDAX order statuses
  #   pending, done, rejected, open (i added 'not-found' for canceled orders)

  # attr_accessor :side, :price, :size, :optional_params, :contract_id, :strategy_type

  #-------------------------------------------------
  #    class methods
  #-------------------------------------------------
  def self.submit_order(order_type, price, size, optional_params, contract_id, strategy, algorithm)
    size            = size.to_s || ORDER_SIZE.to_s
    optional_params = optional_params || { post_only: true }
    strategy_type   = strategy
    # @type           = 'limit' # GDAX default
    # @product_id     = 'BTC-USD' # Coinbase gem default

    case order_type
    when 'buy'
      response = GDAX::Connection.new.rest_client.buy(size, price, optional_params)
    when 'sell'
      response = GDAX::Connection.new.rest_client.sell(size, price, optional_params)
    end

    if response
      price = response.keys.include?('price') ? response['price'] : 'unknown price'
      Rails.logger.info "#{strategy_type.capitalize} (#{algorithm}) order successful: #{order_type.upcase} @ #{response['price']}"
      store_order(response, order_type, contract_id, strategy_type, algorithm)
    end
    response
  rescue Coinbase::Exchange::BadRequestError => gdax_error
    Rails.logger.info "GDAX error (order submit): #{gdax_error}"
    nil
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    Rails.logger.info "GDAX rate limit error (order submit): #{rate_limit_error}"
    nil
  rescue Net::ReadTimeout => timeout_error
    Rails.logger.info "GDAX timeout error (order submit): #{timeout_error}"
    nil
  rescue OpenSSL::SSL::SSLErrorWaitReadable => ssl_error
    Rails.logger.info "GDAX SSL error (order submit): #{ssl_error}"
    nil
  rescue Coinbase::Exchange::InternalServerError => server_error
    Rails.logger.info "GDAX server error (order submit): #{server_error}"
    nil
  end

  def self.place_buy(bid, contract_id=nil)
    optional_params = { post_only: true }
    submit_order('buy', bid, ORDER_SIZE, optional_params, contract_id, 'market-maker', nil)
  end

  def self.place_sell(ask, contract_id=nil)
    optional_params = { post_only: true }
    submit_order('sell', ask, ORDER_SIZE, optional_params, contract_id, 'market-maker', nil)
  end

  def self.buy_price
    current_bid = GDAX::MarketData.current_bid
    if current_bid == 0.0
      return current_bid
    else
      # (current_bid - MARGIN).round(2)
      # available_buys   = (Account.gdax_usdollar_account.balance / (current_bid * ORDER_SIZE)).round
      # spread_increment = ((current_bid * SPREAD_PERCENT) / (available_buys + 1)).round(3) * 0.75
      # (current_bid - spread_increment).round(2)

      profit_percent = 1.0 - PROFIT_PERCENT
      (current_bid * profit_percent).round(2)
    end
  end

  def self.new_buy_price
    current_bid = GDAX::MarketData.current_bid
    if current_bid == 0.0
      return current_bid
    else
      # available_buys = (Account.gdax_usdollar_account.balance / (current_bid * ORDER_SIZE)).round
      # available_buys = 10 if available_buys > 10

      buys_without_sells = BuyOrder.where(status: ['pending', 'open']).where(contract_id: Contract.where.not(id: SellOrder.done.select(:contract_id).distinct)).order(:requested_price)
      existent_buys      = open_orders.select {|o| buys_without_sells.pluck(:gdax_id).include?(o.id) }
      multiplier         = INCREMENTS[existent_buys.count]

      buy_price = (current_bid * (1 - multiplier)).round(2)
      puts "There are #{existent_buys.count} existing buys without matching sell: #{existent_buys.map(&:id)}"
      puts "Current buy price calculation: #{current_bid} * (1 - #{multiplier}) = #{buy_price}"

      buy_price
    end
  end

  def self.ask_price
    current_ask = GDAX::MarketData.current_ask
    if current_ask == 0.0
      return current_ask
    else
      # # (current_ask + MARGIN).round(2)
      # available_sells  = (Account.gdax_bitcoin_account.balance * 100).round
      # spread_increment = ((current_ask * SPREAD_PERCENT) / (available_sells + 1)).round(3) * 0.75
      # (current_ask + spread_increment).round(2)

      profit_percent = 1.0 + PROFIT_PERCENT
      (current_ask * profit_percent).round(2)
    end
  end

  def self.new_ask_price
    current_ask = GDAX::MarketData.current_ask
    if current_ask == 0.0
      return current_ask
    else
      # available_sells = (Account.gdax_bitcoin_account.balance / (current_ask * ORDER_SIZE)).round
      # available_sells = 10 if available_sells > 10

      sells_without_buy = SellOrder.where(status: ['pending', 'open']).where(contract_id: Contract.where.not(id: BuyOrder.done.select(:contract_id).distinct)).order(:requested_price)
      existent_sells    = open_orders.select {|o| sells_without_buy.pluck(:gdax_id).include?(o.id) }
      multiplier        = INCREMENTS[existent_sells.count]

      sell_price = (current_ask * (1 + multiplier)).round(2)
      puts "There are #{existent_sells.count} existing sells without matching buy: #{existent_sells.map(&:id)}"
      puts "Current sell price calculation: #{current_ask} * (1 - #{multiplier}) = #{sell_price}"

      sell_price
    end
  end

  def self.check_status(id)
    GDAX::Connection.new.rest_client.order(id)
  end

  def self.open_orders
    GDAX::Connection.new.rest_client.orders(status: 'open')
  end

  def self.my_highest_open_buy_order
    # find my open buy order that is closest to market price
    open_orders.select {|o| o.side == 'buy' && o.filled_size == 0.0 }.sort_by(&:price).last
  end

  def self.my_lowest_open_sell_order
    # find my open sell order that is closest to market price
    open_orders.select {|o| o.side == 'sell' && o.filled_size == 0.0 }.sort_by(&:price).first
  end

  def self.calculate_filled_price(response)
    return nil if response.executed_value.nil? || response.filled_size.nil? || response.filled_size.zero?
    response.executed_value / response.filled_size
  end

  def self.cancel_stale_orders
    # Does this affect tech-analysis orders??
    exchange_orders = open_orders
                        .select {|o| o.filled_size == 0.0} # we don't want to cancel orders that have been partially filled.
                        .sort_by(&:price)
                        .group_by(&:side) # { 'buy' => [], 'sell' => [] }
    open_buys  = exchange_orders['buy']
    open_sells = exchange_orders['sell']

    lowest_buy   = open_buys.first if open_buys  # && open_buys.count > 10
    highest_sell = open_sells.last if open_sells # && open_sells.count > 10

    Order.find_by(gdax_id: lowest_buy.id).cancel_order   if lowest_buy   && (lowest_buy.created_at   < 5.minutes.ago) && !Contract.recent_buys?
    Order.find_by(gdax_id: highest_sell.id).cancel_order if highest_sell && (highest_sell.created_at < 5.minutes.ago) && !Contract.recent_sells?
  end

  def self.store_order(response, order_type, contract_id, strategy_type, algorithm)
    Rails.logger.info "Storing order #{response['id']}"
    contract = Contract.create_with(strategy_type: strategy_type, algorithm: algorithm).find_or_create_by(id: contract_id)
    contract.update(gdax_buy_order_id: response.id)  if order_type == 'buy'
    contract.update(gdax_sell_order_id: response.id) if order_type == 'sell'

    price      = response.keys.include?('price') ? response['price'] : nil           # NOTE: market orders do not include 'price' in response
    stop_type  = response.keys.include?('stop') ? response['stop'] : nil             # NOTE: orders do not always include 'stop' in response
    stop_price = response.keys.include?('stop_price') ? response['stop_price'] : nil # NOTE: orders do not always include 'stop_price' in response

    contract.orders.create(
      # NOTE: Coinbase-exchange gem automatically converts numeric response values into decimals
      type:                lookup_class_type[order_type],
      gdax_id:             response['id'],
      gdax_price:          price,
      gdax_size:           response['size'],
      gdax_product_id:     response['product_id'],
      gdax_side:           response['side'],
      gdax_stp:            response['stp'],
      gdax_type:           response['type'],
      gdax_post_only:      response['post_only'],
      gdax_created_at:     response['created_at'],
      gdax_filled_fees:    response['fill_fees'],
      gdax_filled_size:    response['filled_size'],
      gdax_executed_value: response['executed_value'],
      gdax_status:         response['status'],
      gdax_settled:        response['settled'],
      quantity:            response['size'],
      requested_price:     price,
      executed_value:      response['executed_value'],
      fees:                response['fill_fees'],
      status:              response['status'],
      strategy_type:       strategy_type,
      stop_type:           stop_type,
      stop_price:          stop_price
      # custom_id:           response['oid'],
      # currency:            response['currency'],
    )
  rescue => error
    Rails.logger.info "Error when storing order: #{error.inspect}"
    Rails.logger.info "response: #{response.inspect}"
  end

  def self.lookup_class_type
    { 'buy' => 'BuyOrder', 'sell' => 'SellOrder' }
  end

  #-------------------------------------------------
  #    instance methods
  #-------------------------------------------------
  def closed?
    CLOSED_STATUSES.include? gdax_status
  end

  def purchased?
    PURCHASED_STATUSES.include? gdax_status
  end

  def done?
    status == 'done'
  end

  def retired?
    status == 'retired'
  end

  def stop_order?
    stop_type.present?
  end

  def check_gdax_status
    GDAX::Connection.new.rest_client.order(self.gdax_id)
  end

  def update_order
    response = check_gdax_status
    if response && response.status != self.gdax_status
      puts "Updating status of #{self.type} #{self.id} from #{self.gdax_status} to #{response.status}"
      price = response.keys.include?('price') ? response.price : nil # NOTE: market orders do not include 'price' in response
      # NOTE: Coinbase-exchange gem automatically converts numeric response values into decimals
      self.update(
        gdax_status:         response.status,
        gdax_price:          price, # price in original request; may not be executed price
        gdax_executed_value: response.executed_value,
        gdax_filled_size:    response.filled_size,
        gdax_filled_fees:    response.fill_fees,
        status:              response.status,
        requested_price:     price,
        filled_price:        Order.calculate_filled_price(response),
        executed_value:      response.executed_value, # filled_price * quantity; does not include fees
        quantity:            response.filled_size,
        fees:                response.fill_fees,
      )
    end
  rescue Coinbase::Exchange::BadRequestError => request_error
    puts "GDAX couldn't check/update status for order #{self.gdax_id}"
  rescue Coinbase::Exchange::NotFoundError => not_found_error
    # this happens after an order has been canceled so we want to update the order's status
    self.update(gdax_status: 'not-found', status: 'not-found')
    puts "GDAX couldn't find order #{self.gdax_id}: #{not_found_error}"
    puts "Updated order #{self.id} with status 'not-found'"
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (update order status): #{rate_limit_error}"
  end

  def cancel_order
    cancellation = GDAX::Connection.new.rest_client.cancel(self.gdax_id)
    self.update(gdax_status: 'not-found', status: 'not-found') if cancellation == {}
  rescue Coinbase::Exchange::BadRequestError => request_error
    puts "GDAX couldn't cancel order #{request_error}"
  rescue Coinbase::Exchange::NotFoundError => not_found_error
    self.update(gdax_status: 'not-found', status: 'not-found')
    puts "GDAX couldn't find/cancel order: #{not_found_error}"
  rescue StandardError => error
    puts "Order cancellation error: #{error.inspect}"
  end

  #=================================================
    private
  #=================================================

end