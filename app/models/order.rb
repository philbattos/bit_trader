class Order < ActiveRecord::Base

  belongs_to :contract

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

  def self.submit(order_type, price) # should this be an instance method??
    type       = 'limit' # default
    side       = order_type
    product_id = 'BTC-USD'
    price      = price
    size       = '0.01'
    post_only  = true

    request_path = '/orders'
    request_body = { "type" => "#{type}", "side" => "#{side}", "product_id" => "#{product_id}", "price" => "#{price}", "size" => "#{size}", "post_only" => "#{post_only}" }.to_json
    request_info = "#{timestamp}POST#{request_path}#{request_body}"
    request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

    puts "request_body: #{request_body.inspect}"
    response = send_post_request(request_path, request_body, request_hash)
    # puts "response: #{response.inspect}"
    response_body = JSON.parse(response.body)
    puts "response_body: #{response_body.inspect}\n\n"
    if response.status == 200
      Order.create(
        type:            lookup_class_type[order_type],
        gdax_id:         response_body['id'],
        gdax_type:       response_body['type'],
        gdax_side:       response_body['side'],
        gdax_product_id: response_body['product_id'],
        amount:          response_body['price'].to_f.round(7),
        custom_id:       response_body['oid'],
        gdax_post_only:  response_body['post_only'],
        fees:            response_body['fill_fees'].to_f.round(7),
        # currency:        response_body['currency'],
      )
    end
    response_body["response-status"] = response.status
    response_body
  rescue Net::ReadTimeout => timeout_error
    puts "Timeout error: #{timeout_error}"
    Rails.logger.error { "#{timeout_error.message}" }
    retry
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

  def self.fetch_ticker
    request_path = "/products/BTC-USD/ticker"
    request_info = "#{timestamp}GET#{request_path}"
    request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

    send_get_request(request_path, request_hash)
  end

  def self.check_status(id)
    request_path = "/orders/#{id}"
    request_info = "#{timestamp}GET#{request_path}"
    request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

    send_get_request(request_path, request_hash)
    # JSON.parse(response)
  end

  #=================================================
    private
  #=================================================

    def self.send_post_request(path, body, request_hash)
      http_client.post path do |request|
        request.headers['Content-Type']         = 'application/json'
        request.headers['CB-ACCESS-KEY']        = ENV['GDAX_API_KEY']
        request.headers['CB-ACCESS-SIGN']       = api_signature(request_hash)
        request.headers['CB-ACCESS-TIMESTAMP']  = timestamp
        request.headers['CB-ACCESS-PASSPHRASE'] = ENV['GDAX_API_PASSPHRASE']
        request.body                            = body
      end
    end

    def self.send_get_request(path, request_hash)
      http_client.get path do |request|
        request.headers['Content-Type']         = 'application/json'
        request.headers['CB-ACCESS-KEY']        = ENV['GDAX_API_KEY']
        request.headers['CB-ACCESS-SIGN']       = api_signature(request_hash)
        request.headers['CB-ACCESS-TIMESTAMP']  = timestamp
        request.headers['CB-ACCESS-PASSPHRASE'] = ENV['GDAX_API_PASSPHRASE']
      end
    end

    def self.http_client
      # move this into a module so it can be reused in multiple models
      Faraday.new(url: ENV['GDAX_BASE_URL']) do |faraday|
        # faraday.response :raise_error
        faraday.adapter  Faraday.default_adapter
      end
    end

    def self.timestamp
      Time.now.to_i.to_s
      # @timestamp ||= Time.now.to_i.to_s
    end

    def self.secret_hash
      Base64.decode64(ENV['GDAX_API_SECRET'])
    end

    def self.api_signature(request_hash)
      Base64.strict_encode64(request_hash)
    end

    def self.lookup_class_type
      { 'buy' => 'BuyOrder', 'sell' => 'SellOrder' }
    end

end