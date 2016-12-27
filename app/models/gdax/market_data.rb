module GDAX
  class MarketData < ActiveRecord::Base
    set_table_name = 'market_data'

    scope :trades_since, -> (date) { where(gdax_time: date..Time.now) }

    def self.save_trade(trade_data)
      trade_data  = trade_data.to_hash.symbolize_keys
      core_fields = unchanged_names(trade_data)

      GDAX::MarketData.create(core_fields) do |market|
        market.trade_type = trade_data[:side]
        market.quantity   = trade_data[:size]
        market.price      = trade_data[:price].to_d
        market.gdax_time  = trade_data[:time]
      end
    end

    def self.unchanged_names(trade_data)
      # NOTE: These fields are named the same as the GDAX json response so they can be saved "as is".
      #       The fields that have different names need to be correctly assigned before saving the object.
      trade_data.slice(
        :trade_id,
        :maker_order_id,
        :taker_order_id,
        :product_id,
        :sequence
      )
    end

    def self.calculate_average(date)
      trades = trades_since(date)
      if trades.present?
        (trades.pluck(:price).sum / trades.count).round(2)
      else
        0
      end
    end
  end
end