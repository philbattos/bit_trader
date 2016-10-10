class CreateOrders < ActiveRecord::Migration[5.0]
  def change
    create_table :orders do |t|
      t.string :gdax_id
      t.string :gdax_type
      t.string :gdax_side
      t.string :gdax_product_id
      t.decimal :amount, precision: 15, scale: 8
      t.string :custom_id
      t.string :currency
      t.boolean :gdax_post_only
      t.integer :contract_id
      t.decimal :fees, precision: 15, scale: 8
      t.string :type # used for identifying BuyOrder and SellOrder subclasses

      t.timestamps
    end
  end
end
