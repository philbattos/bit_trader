desc "Check current profit amount"
task metrics: :environment do
  total_contracts = Contract.resolved
  total_profit    = total_contracts.sum(:roi)
  puts "Current profit: $#{total_profit} (#{total_contracts.count} contracts since 12/31/2016)"

  unprofitable_contracts = Contract.resolved.where("roi < 0")
  puts "There have been #{unprofitable_contracts.count} unprofitable contracts that have lost a total of $#{unprofitable_contracts.sum(:roi)}"

  Metric.transaction do 
    puts "Saving metrics to db...."
    Metric.save_current_data
  end

  # Moved from data-integrity task to prevent two tasks from running at the same time
  puts "============================================================="

  orders_without_executed_value = Order.done.where(executed_value: nil)
  puts "These orders do not have an executed_value: #{orders_without_executed_value.count}"

  mismatched_buy_contracts = Contract.joins(:buy_orders).where(orders: {status: Order::ACTIVE_STATUSES}).where.not("contracts.gdax_buy_order_id = orders.gdax_id")
  puts "These contracts have gdax_buy_order_ids that don't match their BUY orders: #{mismatched_buy_contracts.pluck(:id)}."

  mismatched_sell_contracts = Contract.joins(:sell_orders).where(orders: {status: Order::ACTIVE_STATUSES}).where.not("contracts.gdax_sell_order_id = orders.gdax_id")
  puts "These contracts have gdax_sell_order_ids that don't match their SELL orders: #{mismatched_sell_contracts.pluck(:id)}."

  multiple_active_buys = BuyOrder.active.select(:id).group(:contract_id).having("COUNT(contract_id) > 1")
  puts "These contracts have more than one active BUY order: #{multiple_active_buys.count}"

  multiple_active_sells = SellOrder.active.select(:id).group(:contract_id).having("COUNT(contract_id) > 1")
  puts "These contracts have more than one active SELL order: #{multiple_active_sells.count}"

  orphaned_orders = Order.where(contract_id: nil)
  puts "These orders do not have an associated contract: #{orphaned_orders.pluck(:id)}"

  mismatched_statuses = Order.where("gdax_status != status AND created_at < ?", 1.hour.ago)
  puts "These orders are at least an hour old and have a status mismatch (gdax_status is different from status): #{mismatched_statuses.pluck(:id, :gdax_status, :status)}"

  puts "============================================================="

end