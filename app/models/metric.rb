class Metric < ActiveRecord::Base

  scope :with_averages, -> { where.not(average_15_min: nil) }
  # scope :trending_down, -> { with_averages.where("average_4_hour > average_1_hour").where("average_1_hour > average_15_min").where("average_15_min > bitcoin_price")

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

    metric = Metric.create(
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

    metric.update(average_15_min: GDAX::MarketData.calculate_average(15.minutes.ago))
    metric.update(average_1_hour: GDAX::MarketData.calculate_average(1.hour.ago))
    metric.update(average_4_hour: GDAX::MarketData.calculate_average(4.hours.ago))
    metric.update(average_12_hour: GDAX::MarketData.calculate_average(12.hours.ago))
    metric.update(average_24_hour: GDAX::MarketData.calculate_average(24.hours.ago))
    metric.update(average_3_day: GDAX::MarketData.calculate_average(3.days.ago))
    metric.update(average_7_day: GDAX::MarketData.calculate_average(7.days.ago))
    metric.update(average_15_day: GDAX::MarketData.calculate_average(15.days.ago))
    # metric.update(average_30_day: GDAX::MarketData.calculate_average(30.days.ago))
  end

end