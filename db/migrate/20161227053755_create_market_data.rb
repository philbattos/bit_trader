class CreateMarketData < ActiveRecord::Migration[5.0]
  def change
    create_table :market_data do |t|
      t.integer   :trade_id
      t.string    :maker_order_id
      t.string    :taker_order_id
      t.string    :trade_type # "buy" or "sell"
      t.decimal   :quantity,      precision: 15, scale: 8
      t.decimal   :price,         precision: 15, scale: 8
      t.string    :product_id
      t.integer   :sequence
      t.datetime  :gdax_time

      t.timestamps
    end
  end
end
