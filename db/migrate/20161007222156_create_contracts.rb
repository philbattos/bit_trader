class CreateContracts < ActiveRecord::Migration[5.0]
  def change
    create_table :contracts do |t|
      # t.string :buy_order_id
      # t.string :sell_order_id
      t.decimal :difference, precision: 15, scale: 8

      t.timestamps
    end
  end
end
