class Order < ActiveRecord::Base

  belongs_to :contract

  scope :resolved,   -> { where(status: CLOSED_STATUSES) }
  scope :unresolved, -> { where.not(id: resolved) }
  scope :active,     -> { where(status: ACTIVE_STATUSES) }
  # scope :inactive,   -> { where(updated_at: Date.parse('october 8 2016')..2.hours.ago) }
  scope :purchased,  -> { where(status: PURCHASED_STATUSES) }
  scope :canceled,   -> { where(status: 'not-found') }
  scope :done,       -> { where(status: 'done') }
  scope :retired,    -> { where(status: 'retired') }
  # NOTE: unfilled orders that are canceled are given a status of 'done' and deleted from GDAX
  #       partially filled orders that are canceled are given a status of 'done' and a done_reason of 'canceled'

  validates :contract, presence: true # all orders should be associated with a contract

  CLOSED_STATUSES    = %w[ done rejected not-found retired ]
  PURCHASED_STATUSES = %w[ done open ]
  ACTIVE_STATUSES    = %w[ done open pending ]
  INACTIVE_STATUSES  = %w[ rejected not-found ] << nil # nil should be considered an "inactive" status

  # TODO: add validation for gdax_id (every order should have one)
  # TODO: currently, we can create an order without an associated contract but it would be better if
  #       every order had an associated contract. find a way to build orders and contracts together
  #       and then add validations to prevent orphaned orders and contracts

  # attr_accessor :type, :side, :product_id, :price, :size, :post_only

  # def initialize(side, price)
  #   # @type       = 'limit' # default
  #   # @side       = side
  #   # @product_id = 'BTC-USD'
  #   # @price      = price
  #   # @size       = '0.01'
  #   # @post_only  = true
  # end

  # NOTE: Available product IDs:
  #   BTC-USD, BTC-GBP, BTC-EUR, ETH-USD, ETH-BTC, LTC-USD, LTC-BTC
  # NOTE: GDAX order statuses
  #   pending, done, rejected, open (i added 'not-found' for canceled orders)

  def cancel
    update(status: 'canceled')
  end

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

  def self.submit_market_order(order_type, price, contract_id) # should this be an instance method??
    price = price.to_s
    size  = '0.01'

    case order_type
    when 'buy'
      response = GDAX::Connection.new.rest_client.buy(size, price)
    when 'sell'
      response = GDAX::Connection.new.rest_client.sell(size, price)
    end

    if response
      puts "Order successful: Market #{order_type.upcase} @ #{response['price']}"
      store_order(response, order_type, contract_id)
    end
    response
  rescue Coinbase::Exchange::BadRequestError => gdax_error
    puts "GDAX error (order submit): #{gdax_error}"
    nil
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (order submit): #{rate_limit_error}"
    nil
  rescue Net::ReadTimeout => timeout_error
    puts "GDAX timeout error (order submit): #{timeout_error}"
    nil
  rescue OpenSSL::SSL::SSLErrorWaitReadable => ssl_error
    puts "GDAX SSL error (order submit): #{ssl_error}"
    nil
  rescue Coinbase::Exchange::InternalServerError => server_error
    puts "GDAX server error (order submit): #{server_error}"
    nil
  end

  def self.submit(order_type, price, contract_id) # should this be an instance method??
    # type       = 'limit' # default
    # side       = order_type
    # product_id = 'BTC-USD'
    # post_only  = true
    price = price.to_s
    size  = '0.01'
    optional_params = {
      post_only: true,
      # time_in_force: 'GTT',
      # cancel_after: 'hour' # available options: min, hour, day (presumably this means we can set an order to be canceled after 1 minute, or 1 hour, or 1 day)
    }

    # TODO: add check of account balance to avoid multitude of "insufficient funds" errors

    case order_type
    when 'buy'
      response = GDAX::Connection.new.rest_client.buy(size, price, optional_params)
    when 'sell'
      response = GDAX::Connection.new.rest_client.sell(size, price, optional_params)
    end

    if response
      puts "Order successful: #{order_type.upcase} @ #{response['price']}"
      store_order(response, order_type, contract_id)
    end
    response
  rescue Coinbase::Exchange::BadRequestError => gdax_error
    puts "GDAX error (order submit): #{gdax_error}"
    nil
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (order submit): #{rate_limit_error}"
    nil
  rescue Net::ReadTimeout => timeout_error
    puts "GDAX timeout error (order submit): #{timeout_error}"
    nil
  rescue OpenSSL::SSL::SSLErrorWaitReadable => ssl_error
    puts "GDAX SSL error (order submit): #{ssl_error}"
    nil
  rescue Coinbase::Exchange::InternalServerError => server_error
    puts "GDAX server error (order submit): #{server_error}"
    nil
  end

  def self.place_buy(bid, contract_id=nil)
    submit('buy', bid, contract_id)
  end

  def self.place_sell(ask, contract_id=nil)
    submit('sell', ask, contract_id)
  end

  # def self.fetch_all
  #   request_path = '/orders'
  #   request_info = "#{timestamp}GET#{request_path}"
  #   request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

  #   send_get_request(request_path, request_hash)
  # end

  # def self.fetch_single(order_id)
  #   request_path = "/orders/#{order_id}"
  #   request_info = "#{timestamp}GET#{request_path}"
  #   request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

  #   send_get_request(request_path, request_hash)
  # end

  def self.check_status(id)
    GDAX::Connection.new.rest_client.order(id)
  end

  def self.update_status
    order = Order.unresolved.sample # for now, we are checking the status of one randomly selected order at a time
    if order
      response = check_status(order.gdax_id)
      if response && response['status'] != order.gdax_status
        puts "Updating status of #{order.type} #{order.id} from #{order.gdax_status} to #{response['status']}"
        order.update(
          gdax_status: response['status'],
          status:      response['status']
        )
      end
    end
  rescue Coinbase::Exchange::BadRequestError => request_error
    puts "GDAX couldn't check/update status for order #{order.gdax_id}"
  rescue Coinbase::Exchange::NotFoundError => not_found_error
    # this happens after an order has been canceled so we want to update the order's status
    order.update(gdax_status: 'not-found', status: 'not-found')
    puts "GDAX couldn't find order #{order.gdax_id}: #{not_found_error}"
    puts "Updated order #{order.id} with status 'not-found'"
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (update order status): #{rate_limit_error}"
  end

  def self.cancel_stale_orders
    open_orders = GDAX::Connection.new.rest_client.orders(status: 'open').sort_by(&:price).group_by(&:side) # { 'buy' => [], 'sell' => [] }
    open_buys   = open_orders['buy']
    open_sells  = open_orders['sell']

    lowest_buy   = open_buys.first if open_buys  # && open_buys.count > 10
    highest_sell = open_sells.last if open_sells # && open_sells.count > 10

    cancel_order(lowest_buy.id)   if lowest_buy   && (lowest_buy.created_at   < 5.minutes.ago) && !Contract.recent_buys?
    cancel_order(highest_sell.id) if highest_sell && (highest_sell.created_at < 5.minutes.ago) && !Contract.recent_sells?
  end

  def self.cancel_order(gdax_id)
    GDAX::Connection.new.rest_client.cancel(gdax_id)
  rescue Coinbase::Exchange::BadRequestError => request_error
    puts "GDAX couldn't cancel order #{request_error}"
  rescue Coinbase::Exchange::NotFoundError => not_found_error
    # order.update(gdax_status: 'not-found', status: 'not-found')
    puts "GDAX couldn't find/cancel order: #{not_found_error}"
  rescue StandardError => error
    puts "Order cancellation error: #{error.inspect}"
  end

  #=================================================
    private
  #=================================================

    def self.store_order(response, order_type, contract_id)
      puts "Storing order #{response['id']}"
      contract = Contract.find_or_create_by(id: contract_id)
      contract.orders.create(
        type:                lookup_class_type[order_type],
        gdax_id:             response['id'],
        gdax_price:          response['price'],
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
        quantity:            find_quantity(response['size']),
        price:               find_price(response['price']),
        fees:                find_fill_fees(response['fill_fees']),
        status:              response['status'],
        # custom_id:           response['oid'],
        # currency:            response['currency'],
      )
    end

    def self.lookup_class_type
      { 'buy' => 'BuyOrder', 'sell' => 'SellOrder' }
    end

    def self.find_quantity(size)
      size.nil? ? nil : size.to_d.round(7)
    end

    def self.find_price(price)
      price.nil? ? nil : price.to_d.round(7)
    end

    def self.find_fill_fees(fees)
      fees.nil? ? nil : fees.to_d.round(7)
    end

end