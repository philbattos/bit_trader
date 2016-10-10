class CreateAccounts < ActiveRecord::Migration[5.0]
  def change
    create_table :accounts do |t|
      t.string :gdax_id
      t.string :currency

      t.timestamps
    end
  end
end
