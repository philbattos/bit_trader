class Order < ActiveRecord::Base

  belongs_to :contract

  scope :resolved,   -> { where(status: CLOSED_STATUSES) }
  scope :unresolved, -> { where.not(id: resolved) }
  # NOTE: canceled orders are marked with 'done' status

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
  #   pending, done, rejected, open

  def cancel
    update(status: 'canceled')
  end

  def closed?
    CLOSED_STATUSES.include? gdax_status
  end

  def self.submit(order_type, price) # should this be an instance method??
    return { response_status: 400, response: "invalid price: #{price}" } if price.to_f < 1
    type       = 'limit' # default
    side       = order_type
    product_id = 'BTC-USD'
    price      = price.to_s
    size       = '0.01'
    post_only  = true

    # request_path = '/orders'
    # request_body = { "type" => "#{type}", "side" => "#{side}", "product_id" => "#{product_id}", "price" => "#{price}", "size" => "#{size}", "post_only" => "#{post_only}" }.to_json
    # request_info = "#{timestamp}POST#{request_path}#{request_body}"
    # request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)
    # response     = send_post_request(request_path, request_body, request_hash)
    response = GDAX.new.client.buy(size, price, post_only: true) if order_type == 'buy'
    response = GDAX.new.client.sell(size, price, post_only: true) if order_type == 'sell'

    # if response.status == 200
      # response_body = JSON.parse(response.body, symbolize_names: true)
      # if response_body[:status] != 'rejected'
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
    response
      # else
      #   puts "Request rejected: #{response.inspect}"
      # end
      # response_body[:response_status] = response.status
      # response_body
    # else
    #   puts "Unsuccessful request; order not created: #{response.inspect}"
    #   { response_status: response.status, response: response }
    # end
  rescue Coinbase::Exchange::BadRequestError => gdax_error
    puts "GDAX error: #{gdax_error}"
    nil
  rescue Coinbase::Exchange::RateLimitError => rate_limit_error
    puts "GDAX rate limit error: #{rate_limit_error}"
    nil
  # rescue Faraday::TimeoutError, Net::ReadTimeout => timeout_error
  #   puts "Timeout error: #{timeout_error}"
  #   Rails.logger.error { "#{timeout_error.message}" }
  #   retry
  # rescue Faraday::ConnectionFailed => connection_error
  #   puts "Connection error: #{connection_error}"
  #   Rails.logger.error { "#{connection_error}" }
  #   retry
  # rescue JSON::ParserError => json_parser_error
  #   puts "JSON ParserError (probably CloudFlare DNS resolution error): #{json_parser_error}"
  #   Rails.logger.error { "#{json_parser_error.backtrace}" }
  #   retry
  end

  def self.place_buy(bid)
    submit('buy', bid)
  end

  def self.place_sell(ask)
    submit('sell', ask)
  end

  def self.fetch_all
    request_path = '/orders'
    request_info = "#{timestamp}GET#{request_path}"
    request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

    send_get_request(request_path, request_hash)
  end

  def self.fetch_single(order_id)
    request_path = "/orders/#{order_id}"
    request_info = "#{timestamp}GET#{request_path}"
    request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

    send_get_request(request_path, request_hash)
  end

  # def self.check_status(id)
  #   request_path = "/orders/#{id}"
  #   request_info = "#{timestamp}GET#{request_path}"
  #   request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

  #   send_get_request(request_path, request_hash)
  # end

  # def self.update_status
  #   order = Order.unresolved.sample # for now, we are checking the status of one randomly selected order at a time

  #   if order
  #     response      = check_status(order.gdax_id)
  #     response_body = JSON.parse(response.body, symbolize_names: true)

  #     if response.status == 200
  #       if response_body[:status] != order.gdax_status
  #         order.update(gdax_status: response_body[:status], status: response_body[:status])
  #       end
  #     elsif response.status == 404
  #       order.update(gdax_status: 'not-found', status: 'not-found')
  #       puts "Order not found on GDAX (order #{order.gdax_id}): #{response.inspect}"
  #     else
  #       puts "check status request failed for order #{order.gdax_id}: #{response.inspect}"
  #     end
  #   end
  # end

  def self.check_status(id)
    GDAX.new.client.order(id)
  end

  def self.update_status
    order = Order.unresolved.sample # for now, we are checking the status of one randomly selected order at a time

    if order
      response = check_status(order.gdax_id)
      if response['status'] != order.gdax_status
        order.update(gdax_status: response['status'], status: response['status'])
      end
    end

  rescue Coinbase::Exchange::BadRequestError => request_error
    puts "GDAX couldn't check/update status for order #{order.gdax_id}"
  rescue Coinbase::Exchange::NotFoundError => not_found_error
    puts "GDAX couldn't find order #{order.gdax_id}: #{not_found_error}"
  end

  #=================================================
    private
  #=================================================

    # def self.send_post_request(path, body, request_hash)
    #   http_client.post path do |request|
    #     request.headers['Content-Type']         = 'application/json'
    #     request.headers['CB-ACCESS-KEY']        = ENV['GDAX_API_KEY']
    #     request.headers['CB-ACCESS-SIGN']       = api_signature(request_hash)
    #     request.headers['CB-ACCESS-TIMESTAMP']  = timestamp
    #     request.headers['CB-ACCESS-PASSPHRASE'] = ENV['GDAX_API_PASSPHRASE']
    #     request.body                            = body
    #   end
    # end

    # def self.send_get_request(path, request_hash)
    #   http_client.get path do |request|
    #     request.headers['Content-Type']         = 'application/json'
    #     request.headers['CB-ACCESS-KEY']        = ENV['GDAX_API_KEY']
    #     request.headers['CB-ACCESS-SIGN']       = api_signature(request_hash)
    #     request.headers['CB-ACCESS-TIMESTAMP']  = timestamp
    #     request.headers['CB-ACCESS-PASSPHRASE'] = ENV['GDAX_API_PASSPHRASE']
    #   end
    # end

    # def self.http_client
    #   # move this into a module so it can be reused in multiple models
    #   Faraday.new(url: ENV['GDAX_BASE_URL']) do |faraday|
    #     # faraday.response :raise_error
    #     faraday.adapter  Faraday.default_adapter
    #   end
    # end

    # def self.timestamp
    #   Time.now.to_i.to_s
    #   # @timestamp ||= Time.now.to_i.to_s
    # end

    # def self.secret_hash
    #   Base64.decode64(ENV['GDAX_API_SECRET'])
    # end

    # def self.api_signature(request_hash)
    #   Base64.strict_encode64(request_hash)
    # end

    def self.lookup_class_type
      { 'buy' => 'BuyOrder', 'sell' => 'SellOrder' }
    end

end