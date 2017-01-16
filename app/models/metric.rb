class Metric < ActiveRecord::Base

  def self.save_current_data
    dollar_balance        = Account.gdax_usdollar_account.balance
    bitcoin_balance       = Account.gdax_bitcoin_account.balance
    bitcoin_price         = GDAX::MarketData.last_trade.price
    account_value         = (bitcoin_balance * bitcoin_price) + dollar_balance
    total_roi             = Contract.resolved.sum(:roi)
    roi_percent           = total_roi / Contract.resolved.count
    unresolved_contracts  = Contract.unresolved.count
    matched_contracts     = Contract.matched.count
    open_orders           = Order.unresolved.count

    Metric.create(
      us_dollar_balance:    dollar_balance,
      bitcoin_balance:      bitcoin_balance,
      bitcoin_price:        bitcoin_price,
      account_value:        account_value,
      total_roi:            total_roi,
      roi_percent:          roi_percent,
      unresolved_contracts: unresolved_contracts,
      matched_contracts:    matched_contracts,
      open_orders:          open_orders
    )
  end

end