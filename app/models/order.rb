class Order < ActiveRecord::Base

  belongs_to :contract

  scope :resolved,   -> { where(status: CLOSED_STATUSES) }
  scope :unresolved, -> { where.not(id: resolved) }
  # NOTE: unfilled orders that are canceled are given a status of 'done' and deleted from GDAX
  #       partially filled orders that are canceled are given a status of 'done' and a done_reason of 'canceled'

  CLOSED_STATUSES = %w[ done rejected not-found ]

  # TODO: add validation for gdax_id (every order should have one)

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

  def self.submit(order_type, price) # should this be an instance method??
    # type       = 'limit' # default
    # side       = order_type
    # product_id = 'BTC-USD'
    # post_only  = true
    price = price.to_s
    size  = '0.01'

    case order_type
    when 'buy'
      response = GDAX.new.client.buy(size, price, post_only: true)
    when 'sell'
      response = GDAX.new.client.sell(size, price, post_only: true)
    end

    store_order(response, order_type) if response
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

  def self.place_buy(bid)
    submit('buy', bid)
  end

  def self.place_sell(ask)
    submit('sell', ask)
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
    GDAX.new.client.order(id)
  end

  def self.update_status
    order = Order.unresolved.sample # for now, we are checking the status of one randomly selected order at a time
    if order
      response = check_status(order.gdax_id)
      if response['status'] != order.gdax_status
        puts "Updating status of order #{order.id} from #{order.gdax_status} to #{response['status']}"
        order.update(gdax_status: response['status'], status: response['status'])
      end
    end
  rescue Coinbase::Exchange::BadRequestError => request_error
    puts "GDAX couldn't check/update status for order #{order.gdax_id}"
  rescue Coinbase::Exchange::NotFoundError => not_found_error
    # this happens after an order has been canceled so we want to update the order's status
    order.update(gdax_status: 'not-found', status: 'not-found')
    puts "GDAX couldn't find order #{order.gdax_id}: #{not_found_error}"
    puts "Updated order #{order.gdax_id} with status 'not-found'"
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error (update order status): #{rate_limit_error}"
  end

  #=================================================
    private
  #=================================================

    def self.store_order(response, order_type)
      puts "Storing order #{response['id']}"
      Order.create(
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
        gdax_filled_fees:    response['filled_fees'],
        gdax_filled_size:    response['filled_size'],
        gdax_executed_value: response['executed_value'],
        gdax_status:         response['status'],
        gdax_settled:        response['settled'],
        quantity:            response['size'].to_f.round(7),
        price:               response['price'].to_f.round(7),
        fees:                response['fill_fees'].to_f.round(7),
        status:              response['status'],
        # custom_id:           response['oid'],
        # currency:            response['currency'],
      )
    end

    def self.lookup_class_type
      { 'buy' => 'BuyOrder', 'sell' => 'SellOrder' }
    end

end