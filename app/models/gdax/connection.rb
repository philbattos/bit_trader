module GDAX
  class Connection

    API_KEY    = ENV['GDAX_API_KEY']
    API_SECRET = ENV['GDAX_API_SECRET']
    API_PASS   = ENV['GDAX_API_PASSPHRASE']

    def rest_client
      @client ||= Coinbase::Exchange::Client.new(API_KEY, API_SECRET, API_PASS)
    end

    def async_client
      @client ||= Coinbase::Exchange::AsyncClient.new(API_KEY, API_SECRET, API_PASS)
    end

    def websocket
      Coinbase::Exchange::Websocket.new(keepalive: true)
    end

  end
end