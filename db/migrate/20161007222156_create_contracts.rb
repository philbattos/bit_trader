class CreateContracts < ActiveRecord::Migration[5.0]
  def change
    create_table :contracts do |t|
      t.string   :gdax_buy_order_id
      t.string   :gdax_sell_order_id

      t.decimal  :roi, precision: 15, scale: 8
      t.string   :status
      t.datetime :completion_date

      t.timestamps
    end
  end
end
