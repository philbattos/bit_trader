desc "Poll exchange and store all trades"
task track_trades: :environment do
  GDAX::MarketData.poll
end