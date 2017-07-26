WITH trades AS (
  SELECT ROW_NUMBER() OVER(ORDER BY trade_id) AS weight,
         ROUND(price,2) AS trade_price
  FROM market_data
  WHERE created_at > '#{date}' AND created_at < now()
)
SELECT ROUND(SUM(trade_price * weight) / SUM(weight), 2) AS weighted_average
FROM trades;