desc "Check current profit amount"
task metrics: :environment do
  total_profit     = Order.total_profit
  completed_profit = Order.completed_profit

  completed_buys   = BuyOrder.done.inactive.count
  completed_sells  = SellOrder.done.inactive.count
  difference       = completed_sells - completed_buys

  puts "Current profit: #{total_profit}"
  puts "Completed profit: #{completed_profit}"
  puts "Completed orders: #{completed_buys} buys, #{completed_sells} sells (#{difference} sells difference)"
end