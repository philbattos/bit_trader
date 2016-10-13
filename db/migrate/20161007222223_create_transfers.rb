class CreateTransfers < ActiveRecord::Migration[5.0]
  def change
    create_table :transfers do |t|
      t.string  :from_account_id
      t.string  :from_account_name
      t.string  :to_account_id
      t.string  :to_account_name
      t.decimal :amount, precision: 15, scale: 8

      t.timestamps
    end
  end
end
