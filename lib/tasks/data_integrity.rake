desc "Periodically check for data integrity"
task data_integrity: :environment do

  Rails.logger.info "============================================================="

  account_vs_market = Account.account_vs_market_ratio
  Rails.logger.info "Account Value vs Market ratio: #{account_vs_market.round(5)}"

  orders_without_executed_value = Order.done.where(executed_value: nil)
  Rails.logger.info "These orders do not have an executed_value: #{orders_without_executed_value.count}"

  mismatched_buy_contracts = Contract.joins(:buy_orders).where(orders: {status: Order::ACTIVE_STATUSES}).where.not("contracts.gdax_buy_order_id = orders.gdax_id")
  Rails.logger.info "These contracts have gdax_buy_order_ids that don't match their BUY orders: #{mismatched_buy_contracts.pluck(:id)}."

  mismatched_sell_contracts = Contract.joins(:sell_orders).where(orders: {status: Order::ACTIVE_STATUSES}).where.not("contracts.gdax_sell_order_id = orders.gdax_id")
  Rails.logger.info "These contracts have gdax_sell_order_ids that don't match their SELL orders: #{mismatched_sell_contracts.pluck(:id)}."

  multiple_active_buys = BuyOrder.active.select(:id).group(:contract_id).having("COUNT(contract_id) > 1")
  Rails.logger.info "These contracts have more than one active BUY order: #{multiple_active_buys.count}"

  multiple_active_sells = SellOrder.active.select(:id).group(:contract_id).having("COUNT(contract_id) > 1")
  Rails.logger.info "These contracts have more than one active SELL order: #{multiple_active_sells.count}"

  orphaned_orders = Order.where(contract_id: nil)
  Rails.logger.info "These orders do not have an associated contract: #{orphaned_orders.pluck(:id)}"

  mismatched_statuses = Order.where("gdax_status != status AND created_at < ?", 1.hour.ago)
  Rails.logger.info "These orders are at least an hour old and have a status mismatch (gdax_status is different from status): #{mismatched_statuses.pluck(:id, :gdax_status, :status)}"

  Rails.logger.info "============================================================="

end
