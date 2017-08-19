# current weighted average since {date}
WITH trades AS (
  SELECT ROW_NUMBER() OVER(ORDER BY trade_id) AS weight,
         ROUND(price,2) AS trade_price
  FROM market_data
  WHERE created_at > '#{date}' AND created_at < NOW()
)
SELECT ROUND(SUM(trade_price * weight) / SUM(weight), 2) AS weighted_average
FROM trades;
# result => {'weighted_average' => 123.45}

# weighted average values
WITH trades AS (
  SELECT ROW_NUMBER() OVER(ORDER BY trade_id) AS weight,
         ROUND(price,2) AS trade_price
  FROM market_data
  WHERE created_at > '#{date}' AND created_at < NOW()
)
SELECT * FROM trades;
# result => {'weight' => [1,2,3,...], 'trade_price' => ['123.45', '234.56', '345.67',...]}

###############################################

WITH current AS (
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
LIMIT 1;
