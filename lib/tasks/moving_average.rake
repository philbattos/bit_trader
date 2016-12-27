desc "Calculate average trade prices"
task moving_average: :environment do

  hourly_average = GDAX::MarketData.calculate_average(1.hour.ago)
  puts "The average trade price for the last hour: $#{hourly_average}" if hourly_average > 0

  six_hour_average = GDAX::MarketData.calculate_average(6.hours.ago)
  puts "The average trade price for the last 6 hours: $#{six_hour_average}" if six_hour_average > 0

  daily_average = GDAX::MarketData.calculate_average(1.day.ago)
  puts "The average trade price for the last 24 hours: $#{daily_average}" if daily_average > 0

end