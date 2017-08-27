class Metric < ActiveRecord::Base

  scope :with_averages, ->        { where.not(average_30_min: nil).where.not(average_4_hour: nil) }
  scope :trending_up,   ->        { with_averages.where("average_30_min > (average_4_hour * 1.01)") }
  scope :trending_down, ->        { with_averages.where("average_30_min < (average_4_hour * 0.99)") }
  scope :since,         -> (date) { where("created_at > ?", date) }

  def self.save_current_data
    # A transaction is necessary (below) to prevent data errors from other queries
    # while the metric is being calculated and saved. A db lock might be better
    # but this transaction seems to work.
    Metric.transaction do
      dollar_balance           = Account.gdax_usdollar_account.balance
      bitcoin_balance          = Account.gdax_bitcoin_account.balance
      bitcoin_price            = GDAX::MarketData.last_trade.price
      account_value            = (bitcoin_balance * bitcoin_price) + dollar_balance
      unresolved_contracts     = Contract.unresolved.count
      matched_contracts        = Contract.matched.count
      open_orders              = Order.unresolved.count
      total_roi                = Contract.resolved.sum(:roi)
      roi_percent              = total_roi / Contract.resolved.count
      trendline_roi            = Contract.trendline.resolved.sum(:roi)
      trendline_roi_percent    = trendline_roi / Contract.trendline.resolved.count
      market_maker_roi         = Contract.market_maker.resolved.sum(:roi)
      market_maker_roi_percent = market_maker_roi / Contract.market_maker.resolved.count

      metric = Metric.create(
        us_dollar_balance:        dollar_balance,
        bitcoin_balance:          bitcoin_balance,
        bitcoin_price:            bitcoin_price,
        account_value:            account_value,
        total_roi:                total_roi,
        roi_percent:              roi_percent,
        trendline_roi:            trendline_roi,
        trendline_roi_percent:    trendline_roi_percent,
        market_maker_roi:         market_maker_roi,
        market_maker_roi_percent: market_maker_roi_percent,
        unresolved_contracts:     unresolved_contracts,
        matched_contracts:        matched_contracts,
        open_orders:              open_orders
      )

      metric.update(average_15_min: GDAX::MarketData.calculate_average(15.minutes.ago))
      metric.update(average_30_min: GDAX::MarketData.calculate_average(30.minutes.ago))
      metric.update(average_1_hour: GDAX::MarketData.calculate_average(1.hour.ago))
      metric.update(average_4_hour: GDAX::MarketData.calculate_average(4.hours.ago))
      metric.update(average_12_hour: GDAX::MarketData.calculate_average(12.hours.ago))
      metric.update(average_13_hour: GDAX::MarketData.calculate_average(13.hours.ago))
      metric.update(average_24_hour: GDAX::MarketData.calculate_average(24.hours.ago))
      metric.update(average_43_hour: GDAX::MarketData.calculate_average(43.hours.ago))
      metric.update(average_3_day: GDAX::MarketData.calculate_average(3.days.ago))
      # metric.update(average_7_day: GDAX::MarketData.calculate_average(7.days.ago))
      # metric.update(average_15_day: GDAX::MarketData.calculate_average(15.days.ago))
      # metric.update(average_30_day: GDAX::MarketData.calculate_average(30.days.ago))

      metric.update(average_weighted_30_minute: GDAX::MarketData.calculate_exponential_average(30.minutes.ago))
      metric.update(average_weighted_1_hour: GDAX::MarketData.calculate_exponential_average(1.hour.ago))
      metric.update(average_weighted_4_hour: GDAX::MarketData.calculate_exponential_average(4.hours.ago))
      metric.update(average_weighted_6_hour: GDAX::MarketData.calculate_exponential_average(6.hours.ago))
      metric.update(average_weighted_10_hour: GDAX::MarketData.calculate_exponential_average(10.hours.ago))
      metric.update(average_weighted_13_hour: GDAX::MarketData.calculate_exponential_average(13.hours.ago))
      metric.update(average_weighted_21_hour: GDAX::MarketData.calculate_exponential_average(21.hours.ago))
      metric.update(average_weighted_25_hour: GDAX::MarketData.calculate_exponential_average(25.hours.ago))
      metric.update(average_weighted_43_hour: GDAX::MarketData.calculate_exponential_average(43.hours.ago))
    end
  end

  def self.seven_day_range
    metric = self.order(:created_at).last

    if metric.average_7_day.nil?
      -2..-1
    else
      floor   = metric.average_7_day * 0.95
      ceiling = metric.average_7_day * 1.05
      floor..ceiling
    end
  end

  def self.three_day_range
    metric = self.order(:created_at).last

    if metric.average_3_day.nil?
      -2..-1
    else
      floor   = metric.average_3_day * 0.95
      ceiling = metric.average_3_day * 1.05
      floor..ceiling
    end
  end

  def self.fix_skewed_roi(metric_id)
    Metric.where('id > ?', metric_id).each do |m|
      contracts             = Contract.where('created_at < ?', m.created_at)
      total_roi             = contracts.resolved.sum(:roi)
      roi_percent           = total_roi / contracts.resolved.count
      trendline_roi         = contracts.trendline.resolved.sum(:roi)
      trendline_roi_percent = trendline_roi / contracts.trendline.resolved.count
      m.update(total_roi: total_roi, roi_percent: roi_percent, trendline_roi: trendline_roi, trendline_roi_percent: trendline_roi_percent)
    end
  end

end