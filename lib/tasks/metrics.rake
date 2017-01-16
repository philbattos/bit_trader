desc "Check current profit amount"
task metrics: :environment do
  total_contracts = Contract.resolved
  total_profit    = total_contracts.sum(:roi)
  puts "Current profit: $#{total_profit} (#{total_contracts.count} contracts since 12/31/2016)"

  unprofitable_contracts = Contract.resolved.where("roi < 0")
  puts "There have been #{unprofitable_contracts.count} unprofitable contracts that have lost a total of $#{unprofitable_contracts.sum(:roi)}"

  puts "Saving metrics to db...."
  Metric.save_current_data
end