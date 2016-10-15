class GDAX

  API_KEY    = ENV['GDAX_API_KEY']
  API_SECRET = ENV['GDAX_API_SECRET']
  API_PASS   = ENV['GDAX_API_PASSPHRASE']

  def client
    @client ||= Coinbase::Exchange::Client.new(API_KEY, API_SECRET, API_PASS)
  end

end