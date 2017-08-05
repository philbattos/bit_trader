class AddTechnicalAnalysisFields < ActiveRecord::Migration[5.0]
  def change
    rename_column :traders, :moving_average_short, :entry_short
    rename_column :traders, :moving_average_long,  :entry_long

    add_column :traders,   :exit_short,       :decimal
    add_column :traders,   :exit_long,        :decimal
    add_column :traders,   :crossover_buffer, :decimal
    add_column :traders,   :trading_units,    :decimal
    add_column :contracts, :algorithm,        :string

    add_index :market_data, :trade_id
    add_index :market_data, :created_at
    add_index :metrics,     :created_at
    add_index :metrics,     :average_30_min
    add_index :metrics,     :average_13_hour
    add_index :metrics,     :average_43_hour
    add_index :metrics,     :average_weighted_13_hour
    add_index :metrics,     :average_weighted_43_hour
  end
end
