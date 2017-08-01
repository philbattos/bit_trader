class CreateTraders < ActiveRecord::Migration[5.0]
  def change
    create_table :traders do |t|
      t.string  :name
      t.text    :description

      t.boolean :is_active
      t.boolean :is_market_maker
      t.boolean :is_trendline

      t.decimal :moving_average_short, precision: 15, scale: 8
      t.decimal :moving_average_long,  precision: 15, scale: 8

      t.timestamps
    end
  end
end
