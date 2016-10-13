class Market

  BID_DECREMENT = 0.01
  ASK_INCREMENT = 0.10

  def self.poll
    while true
      Contract.resolve_open
      place_buy_order
    end
  end

  def self.place_buy_order
    current_bid = fetch_ticker['bid']
    my_bid      = (current_bid.to_f - BID_DECREMENT).round(7).to_s
    new_order   = Order.place_buy(my_bid)
    # puts "NEW BUY ORDER: #{new_order.inspect}"

    if new_order[:response_status] == 200
      order    = Order.find_by_gdax_id(new_order[:id])
      contract = Contract.create() # order.create_contract() doesn't correctly associate objects
      contract.buy_order = order
    else
      # check if order was created on GDAX
      puts "BUY ORDER FAILED: #{new_order[:response_status]}"
    end
  end

  def self.place_sell_order(id, price)
    my_ask      = (price.to_f + ASK_INCREMENT).round(7).to_s
    new_order   = Order.place_sell(my_ask)
    puts "NEW SELL ORDER: #{new_order.inspect}"
    # TODO: save sell order ID in contract
    new_order
  end

  def self.fetch_ticker
    request_path = "/products/BTC-USD/ticker"
    request_info = "#{timestamp}GET#{request_path}"
    request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

    response = send_get_request(request_path, request_hash).body
    JSON.parse(response)
  end

  def self.current_ask
    fetch_ticker['ask'].to_f.round(7)
  end

  # def self.poll
  #   retry_attempts = 0
  #   begin
  #     # fetch status: open orders? unsold buys? lookup orders in db?
  #     open_orders = JSON.parse(Order.fetch_all.body)
  #     unsold_contracts = Contract.need_sell
  #     # puts "open_orders: #{open_orders.inspect}"
  #     if open_orders.is_a? Hash
  #       if open_orders.has_key?('message') # something went wrong
  #         # create alert
  #         retry_attempts += 1
  #         puts "POLLING ERROR: open_orders response: #{open_orders.inspect}"
  #         next if retry_attempts < 5
  #       end
  #     else
  #       buy_orders, sell_orders = open_orders.partition {|o| o['side'] == 'buy' }
  #       # puts "buy_orders: #{buy_orders.inspect}"

  #       if buy_orders.empty?
  #         place_buy_order # record order ID to match it with a sell order
  #       # elsif orders_paired?
  #       #   place_buy_order
  #       else
  #         # monitor buy orders
  #         # buy_orders = buy_orders.sort_by {|o| o['price'].to_f }.reverse
  #         order         = buy_orders.sample
  #         response      = Order.check_status(order['id'])
  #         response_body = JSON.parse(response.body)

  #         if response.status == 200
  #           # puts "\nOrder status response: #{response.status} \n#{response.inspect} \n\n"
  #           if response_body['status'] == 'done'
  #             place_sell_order(order['id'], order['price'])
  #           else # order has a status other than 'done'
  #             # buy_orders.reject! {|o| o['id'] == order['id'] }
  #             # next
  #           end
  #         elsif response.status == 404 # invalid ID or canceled order
  #           puts "\nOrder status response: #{response.status} \n#{response.inspect} \n\n"
  #           buy_orders.reject! {|o| o['id'] == order['id'] }
  #         else
  #           puts "\nOrder status response: #{response.status} \n#{response.inspect} \n\n"
  #           buy_orders.reject! {|o| o['id'] == order['id'] }
  #         end
  #       end
  #     end
  #     place_buy_order
  #   end until open_orders.count > 8
  # end

  #=================================================
    private
  #=================================================

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

    # def self.buy_order?(orders)
    #   orders.count < 3
    # end

end