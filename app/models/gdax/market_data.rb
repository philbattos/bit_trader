module GDAX
  class MarketData < ActiveRecord::Base
    set_table_name = 'market_data'

    scope :trades_since, -> (date) { where(gdax_time: date..Time.now) }

    def self.poll # opens connection to GDAX firehose, collects all trades, and stores trades in db
      websocket = GDAX::Connection.new.websocket
      websocket.match {|matched_trade| save_trade(matched_trade) } # NOTE: matched_trade is a Coinbase::Exchange::APIObject (but looks like json)

      EM.run do
        websocket.start!
        EM.error_handler { |e|
          p "Websocket Error: #{e.message}"
          p "Websocket Backtrace: #{e.backtrace}"
        }
      end
    end

    def self.last_saved_trade
      order(:trade_id).last
    end

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
      trades_since(date).average(:price).try(:round, 2)
    end

    def self.calculate_exponential_average(date)
      # date should be in format '2017-07-25 17:55:16' or '2017-07-25 17:55:16 +0000' or '2017-07-25 17:55:16 UTC'
      sql_query = "WITH trades AS (
        SELECT ROW_NUMBER() OVER(ORDER BY trade_id) AS weight,
               ROUND(price,2) AS trade_price
        FROM market_data
        WHERE created_at > '#{date}' AND created_at < now()
      )
      SELECT ROUND(SUM(trade_price * weight) / SUM(weight), 2) AS weighted_average
      FROM trades;"
      results = ActiveRecord::Base.connection.execute(sql_query)
      results.first['weighted_average'].to_d
    end

    def self.current_trend(date, interval)
      # NOTE: date should be in format '2017-07-25 17:55:16' or '2017-07-25 17:55:16 +0000' or '2017-07-25 17:55:16 UTC'
      # NOTE: interval is the number of seconds between the currently calculated moving average and a previous calculation
      sql_query = "WITH current AS (
        SELECT ROW_NUMBER() OVER(ORDER BY trade_id) AS current_weight,
               ROUND(price,2) AS current_price
        FROM market_data
        WHERE created_at > (timestamp '#{date}') AND created_at < NOW()
      ), earlier AS (
        SELECT ROW_NUMBER() OVER(ORDER BY trade_id) AS earlier_weight,
               ROUND(price,2) AS earlier_price
        FROM market_data
        WHERE created_at > (timestamp '#{date}' - INTERVAL '#{interval} seconds') AND created_at < (NOW() - INTERVAL '#{interval} seconds')
      )
        SELECT
          (SELECT ROUND(SUM(current_price * current_weight) / SUM(current_weight), 2) FROM current) AS current_average,
          (SELECT ROUND(SUM(earlier_price * earlier_weight) / SUM(earlier_weight), 2) FROM earlier) AS earlier_average
        LIMIT 1;"
      results = ActiveRecord::Base.connection.execute(sql_query)

      Rails.logger.info "Trend results: #{results.first}"

      current_average = results.first['current_average']
      earlier_average = results.first['earlier_average']
      if current_average == earlier_average
        # no trend; do nothing
      elsif current_average > earlier_average
        # trending up
        'TRENDING UP'
      elsif current_average < earlier_average
        # trending down
        'TRENDING DOWN'
      else
        # WTF?!
      end
    end

    def self.orderbook
      GDAX::Connection.new.rest_client.orderbook
    rescue Coinbase::Exchange::RateLimitError => rate_limit_error
      puts "GDAX rate limit error (orderbook): #{rate_limit_error}"
      empty_orderbook
    rescue Coinbase::Exchange::APIError => api_error
      puts "GDAX API error (orderbook): #{api_error}"
      empty_orderbook
    end

    def self.last_trade
      GDAX::Connection.new.rest_client.last_trade
    rescue Coinbase::Exchange::RateLimitError => rate_limit_error
      puts "GDAX rate limit error (last-trade): #{rate_limit_error}"
      empty_orderbook
    rescue Coinbase::Exchange::APIError => api_error
      puts "GDAX API error (last-trade): #{api_error}"
      empty_orderbook
    end

    def self.current_bid
      orderbook.bids.first[0].to_d
    rescue NoMethodError => no_method_error
      puts "NoMethodError (current_bid): #{no_method_error}"
      retry
    end

    def self.current_ask
      orderbook.asks.first[0].to_d
    rescue NoMethodError => no_method_error
      puts "NoMethodError (current_ask): #{no_method_error}"
      retry
    end

    def self.empty_orderbook
      OpenStruct.new({ bids: [[]], asks: [[]] })
    end
  end
end