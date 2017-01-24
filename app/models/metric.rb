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
    # average_15_min        = GDAX::MarketData.calculate_average(15.minutes.ago)
    # average_1_hour        = GDAX::MarketData.calculate_average(1.hour.ago)
    # average_4_hour        = GDAX::MarketData.calculate_average(4.hours.ago)
    # average_12_hour       = GDAX::MarketData.calculate_average(12.hours.ago)
    # average_24_hour       = GDAX::MarketData.calculate_average(24.hours.ago)
    # average_3_day         = GDAX::MarketData.calculate_average(3.days.ago)
    # average_7_day         = GDAX::MarketData.calculate_average(7.days.ago)
    # average_15_day        = GDAX::MarketData.calculate_average(15.days.ago)
    # average_30_day        = GDAX::MarketData.calculate_average(30.days.ago)

    metric = Metric.create(
      us_dollar_balance:    dollar_balance,
      bitcoin_balance:      bitcoin_balance,
      bitcoin_price:        bitcoin_price,
      account_value:        account_value,
      total_roi:            total_roi,
      roi_percent:          roi_percent,
      unresolved_contracts: unresolved_contracts,
      matched_contracts:    matched_contracts,
      open_orders:          open_orders,
      # average_15_min:       average_15_min,
      # average_1_hour:       average_1_hour,
      # average_4_hour:       average_4_hour,
      # average_12_hour:      average_12_hour,
      # average_24_hour:      average_24_hour,
      # average_3_day:        average_3_day,
      # average_7_day:        average_7_day,
      # average_15_day:       average_15_day,
      # average_30_day:       average_30_day
    )

    metric.update(average_15_day: GDAX::MarketData.calculate_average(15.minutes.ago))
    metric.update(average_1_hour: GDAX::MarketData.calculate_average(1.hour.ago))
    metric.update(average_4_hour: GDAX::MarketData.calculate_average(4.hours.ago))
    metric.update(average_12_hour: GDAX::MarketData.calculate_average(12.hours.ago))
    metric.update(average_24_hour: GDAX::MarketData.calculate_average(24.hours.ago))
    # metric.update(average_3_day: GDAX::MarketData.calculate_average(3.days.ago))
    # metric.update(average_7_day: GDAX::MarketData.calculate_average(7.days.ago))
    # metric.update(average_15_day: GDAX::MarketData.calculate_average(15.days.ago))
    # metric.update(average_30_day: GDAX::MarketData.calculate_average(30.days.ago))
  end

end