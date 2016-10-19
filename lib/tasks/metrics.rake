desc "Check current profit amount"
task metrics: :environment do
  total_profit     = Order.total_profit
  completed_profit = Order.completed_profit
  puts "Current profit: #{total_profit}"
  puts "Completed profit: #{completed_profit}"
end