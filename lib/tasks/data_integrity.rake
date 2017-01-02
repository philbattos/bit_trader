desc "Periodically check for data integrity"
task match_ids: :environment do
  mismatched_buy_contracts = Contract.joins(:buy_orders).where(orders: {status: Order::ACTIVE_STATUSES}).where.not("contracts.gdax_buy_order_id = orders.gdax_id")
  puts "These contracts have gdax_buy_order_ids that don't match their BUY orders: #{mismatched_buy_contracts.pluck(:id)}."

  mismatched_sell_contracts = Contract.joins(:sell_orders).where(orders: {status: Order::ACTIVE_STATUSES}).where.not("contracts.gdax_sell_order_id = orders.gdax_id")
  puts "These contracts have gdax_sell_order_ids that don't match their SELL orders: #{mismatched_sell_contracts.pluck(:id)}."
end

task multiple_active_orders: :environment do
  multiple_active_buys = Contract.joins(:buy_orders).group('contracts.id').having("COUNT(orders.status IN ('done', 'open', 'pending')) > 1")
  puts "These contracts have more than one active BUY order: #{multiple_active_buys.count}"

  multiple_active_sells = Contract.joins(:sell_orders).group('contracts.id').having("COUNT(orders.status IN ('done', 'open', 'pending')) > 1")
  puts "These contracts have more than one active SELL order: #{multiple_active_sells.count}"

  # Contract.all.select {|c| c.sell_orders.where(status: ['done', 'open', 'pending']).count > 1}.map(&:id).sort
  # Contract.where(id: SellOrder.select(:contract_id).where(status: ['done', 'pending', 'open']).distinct).count
end

task orphaned_orders: :environment do
  orphaned_orders = Order.where(contract_id: nil)
  puts "These orders do not have an associated contract: #{orphaned_orders.pluck(:id)}"
end

# THINGS TO ADD
# - check if any orders have mis-matched statuses: order.gdax_status differs from order.status
# -