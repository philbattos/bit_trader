desc "Check current profit amount"
task metrics: :environment do
  profit = Order.total_profit
  puts "Current profit: #{profit}"
end