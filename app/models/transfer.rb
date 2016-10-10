class Transfer

  attr_accessor :amount, :sender, :recipient

  def initialize(amount)
    @sender    = ENV['COINBASE_PRIMARY_ACCOUNT_ID']
    @recipient = ENV['GDAX_BTC_ACCOUNT_ID']
    @amount    = amount
  end

  def complete
    request_path = '/deposits/coinbase-account'
    request_body = { "amount" => "#{amount}", "currency" => "BTC", "coinbase_account_id" => "#{sender}" }.to_json
    request_info = "#{timestamp}POST#{request_path}#{request_body}"
    request_hash = OpenSSL::HMAC.digest('sha256', secret_hash, request_info)

    response = send_post_request(request_path, request_body, request_hash)
    response.body
  end

  #=================================================
    private
  #=================================================

    def send_post_request(path, body, request_hash)
      http_client.post path do |request|
        request.headers['Content-Type']         = 'application/json'
        request.headers['CB-ACCESS-KEY']        = ENV['GDAX_API_KEY']
        request.headers['CB-ACCESS-SIGN']       = api_signature(request_hash)
        request.headers['CB-ACCESS-TIMESTAMP']  = timestamp
        request.headers['CB-ACCESS-PASSPHRASE'] = ENV['GDAX_API_PASSPHRASE']
        request.body                            = body
      end
    end

    def http_client
      # move this into a module so it can be reused in multiple models
      Faraday.new(url: ENV['GDAX_BASE_URL']) do |faraday|
        # faraday.response :raise_error
        faraday.adapter  Faraday.default_adapter
      end
    end

    def timestamp
      Time.now.to_i.to_s
      # @timestamp ||= Time.now.to_i.to_s
    end

    def secret_hash
      Base64.decode64(ENV['GDAX_API_SECRET'])
    end

    def api_signature(request_hash)
      Base64.strict_encode64(request_hash)
    end

end