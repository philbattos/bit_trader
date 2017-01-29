# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20170128235612) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.string   "gdax_id"
    t.string   "gdax_currency"
    t.string   "gdax_balance"
    t.string   "gdax_hold"
    t.string   "gdax_available"
    t.string   "gdax_profile_id"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  create_table "contracts", force: :cascade do |t|
    t.string   "gdax_buy_order_id"
    t.string   "gdax_sell_order_id"
    t.decimal  "roi",                precision: 15, scale: 8
    t.string   "status"
    t.datetime "completion_date"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.string   "strategy_type"
    t.index ["roi"], name: "index_contracts_on_roi", using: :btree
    t.index ["status"], name: "index_contracts_on_status", using: :btree
  end

  create_table "market_data", force: :cascade do |t|
    t.integer  "trade_id"
    t.string   "maker_order_id"
    t.string   "taker_order_id"
    t.string   "trade_type"
    t.decimal  "quantity",       precision: 15, scale: 8
    t.decimal  "price",          precision: 15, scale: 8
    t.string   "product_id"
    t.integer  "sequence"
    t.datetime "gdax_time"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.index ["gdax_time"], name: "index_market_data_on_gdax_time", using: :btree
    t.index ["price"], name: "index_market_data_on_price", using: :btree
  end

  create_table "metrics", force: :cascade do |t|
    t.decimal  "us_dollar_balance"
    t.decimal  "bitcoin_balance"
    t.decimal  "bitcoin_price"
    t.decimal  "account_value"
    t.decimal  "total_roi"
    t.decimal  "roi_percent"
    t.integer  "unresolved_contracts"
    t.integer  "matched_contracts"
    t.integer  "open_orders"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
    t.decimal  "average_15_min"
    t.decimal  "average_1_hour"
    t.decimal  "average_4_hour"
    t.decimal  "average_12_hour"
    t.decimal  "average_24_hour"
    t.decimal  "average_3_day"
    t.decimal  "average_7_day"
    t.decimal  "average_15_day"
    t.decimal  "average_30_day"
    t.index ["account_value"], name: "index_metrics_on_account_value", using: :btree
    t.index ["average_12_hour"], name: "index_metrics_on_average_12_hour", using: :btree
    t.index ["average_15_day"], name: "index_metrics_on_average_15_day", using: :btree
    t.index ["average_15_min"], name: "index_metrics_on_average_15_min", using: :btree
    t.index ["average_1_hour"], name: "index_metrics_on_average_1_hour", using: :btree
    t.index ["average_24_hour"], name: "index_metrics_on_average_24_hour", using: :btree
    t.index ["average_30_day"], name: "index_metrics_on_average_30_day", using: :btree
    t.index ["average_3_day"], name: "index_metrics_on_average_3_day", using: :btree
    t.index ["average_4_hour"], name: "index_metrics_on_average_4_hour", using: :btree
    t.index ["average_7_day"], name: "index_metrics_on_average_7_day", using: :btree
    t.index ["bitcoin_price"], name: "index_metrics_on_bitcoin_price", using: :btree
  end

  create_table "orders", force: :cascade do |t|
    t.string   "gdax_id"
    t.string   "gdax_price"
    t.string   "gdax_size"
    t.string   "gdax_product_id"
    t.string   "gdax_side"
    t.string   "gdax_stp"
    t.string   "gdax_type"
    t.boolean  "gdax_post_only"
    t.string   "gdax_created_at"
    t.string   "gdax_filled_fees"
    t.string   "gdax_filled_size"
    t.string   "gdax_executed_value"
    t.string   "gdax_status"
    t.string   "gdax_settled"
    t.decimal  "quantity",            precision: 15, scale: 8
    t.decimal  "price",               precision: 15, scale: 8
    t.integer  "contract_id"
    t.string   "custom_id"
    t.string   "currency"
    t.decimal  "fees",                precision: 15, scale: 8
    t.string   "status"
    t.string   "type"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.string   "strategy_type"
    t.index ["contract_id"], name: "index_orders_on_contract_id", using: :btree
    t.index ["fees"], name: "index_orders_on_fees", using: :btree
    t.index ["price"], name: "index_orders_on_price", using: :btree
    t.index ["quantity"], name: "index_orders_on_quantity", using: :btree
    t.index ["status"], name: "index_orders_on_status", using: :btree
  end

  create_table "transfers", force: :cascade do |t|
    t.string   "from_account_id"
    t.string   "from_account_name"
    t.string   "to_account_id"
    t.string   "to_account_name"
    t.decimal  "amount",            precision: 15, scale: 8
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

end
