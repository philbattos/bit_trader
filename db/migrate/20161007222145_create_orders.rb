class CreateOrders < ActiveRecord::Migration[5.0]
  def change
    create_table :orders do |t|
      t.string  :gdax_id
      t.string  :gdax_price
      t.string  :gdax_size
      t.string  :gdax_product_id
      t.string  :gdax_side
      t.string  :gdax_stp
      t.string  :gdax_type
      t.boolean :gdax_post_only
      t.string  :gdax_created_at
      t.string  :gdax_filled_fees
      t.string  :gdax_filled_size
      t.string  :gdax_executed_value
      t.string  :gdax_status
      t.string  :gdax_settled

      t.decimal :quantity,   precision: 15, scale: 8
      t.decimal :price,      precision: 15, scale: 8
      t.decimal :fees,       precision: 15, scale: 8
      t.string  :currency
      t.string  :status
      t.string  :custom_id
      t.integer :contract_id
      t.string  :type # used for identifying BuyOrder and SellOrder subclasses

      t.timestamps
    end
  end
end
