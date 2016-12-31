desc "Periodically check for data integrity"
task match_ids: :environment do
  mismatched_buy_contracts = Contract.joins(:buy_orders).where.not("contracts.gdax_buy_order_id = orders.gdax_id")
  puts "These contracts have gdax_buy_order_ids that don't match their buy orders: #{mismatched_buy_contracts.pluck(:id)}."

  mismatched_sell_contracts = Contract.joins(:sell_orders).where.not("contracts.gdax_buy_order_id = orders.gdax_id")
  puts "These contracts have gdax_sell_order_ids that don't match their sell orders: #{mismatched_sell_contracts.pluck(:id)}."
end