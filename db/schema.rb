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

ActiveRecord::Schema.define(version: 20170806061619) do

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
    t.string   "algorithm"
    t.index ["roi"], name: "index_contracts_on_roi", using: :btree
    t.index ["status"], name: "index_contracts_on_status", using: :btree
    t.index ["strategy_type"], name: "index_contracts_on_strategy_type", using: :btree
  end

  create_table "market_data", force: :cascade do |t|
    t.bigint   "trade_id"
    t.string   "maker_order_id"
    t.string   "taker_order_id"
    t.string   "trade_type"
    t.decimal  "quantity",       precision: 15, scale: 8
    t.decimal  "price",          precision: 15, scale: 8
    t.string   "product_id"
    t.bigint   "sequence"
    t.datetime "gdax_time"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.index ["created_at"], name: "index_market_data_on_created_at", using: :btree
    t.index ["gdax_time"], name: "index_market_data_on_gdax_time", using: :btree
    t.index ["price"], name: "index_market_data_on_price", using: :btree
    t.index ["trade_id"], name: "index_market_data_on_trade_id", using: :btree
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
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.decimal  "average_15_min"
    t.decimal  "average_1_hour"
    t.decimal  "average_4_hour"
    t.decimal  "average_12_hour"
    t.decimal  "average_24_hour"
    t.decimal  "average_3_day"
    t.decimal  "average_7_day"
    t.decimal  "average_15_day"
    t.decimal  "average_30_day"
    t.decimal  "average_30_min"
    t.decimal  "average_13_hour"
    t.decimal  "average_43_hour"
    t.decimal  "average_weighted_13_hour"
    t.decimal  "average_weighted_43_hour"
    t.decimal  "average_weighted_30_minute"
    t.decimal  "average_weighted_1_hour"
    t.decimal  "average_weighted_4_hour"
    t.decimal  "average_weighted_6_hour"
    t.decimal  "average_weighted_10_hour"
    t.decimal  "average_weighted_21_hour"
    t.decimal  "average_weighted_25_hour"
    t.decimal  "trendline_roi"
    t.decimal  "trendline_roi_percent"
    t.decimal  "market_maker_roi"
    t.decimal  "market_maker_roi_percent"
    t.index ["account_value"], name: "index_metrics_on_account_value", using: :btree
    t.index ["average_12_hour"], name: "index_metrics_on_average_12_hour", using: :btree
    t.index ["average_13_hour"], name: "index_metrics_on_average_13_hour", using: :btree
    t.index ["average_15_day"], name: "index_metrics_on_average_15_day", using: :btree
    t.index ["average_15_min"], name: "index_metrics_on_average_15_min", using: :btree
    t.index ["average_1_hour"], name: "index_metrics_on_average_1_hour", using: :btree
    t.index ["average_24_hour"], name: "index_metrics_on_average_24_hour", using: :btree
    t.index ["average_30_day"], name: "index_metrics_on_average_30_day", using: :btree
    t.index ["average_30_min"], name: "index_metrics_on_average_30_min", using: :btree
    t.index ["average_3_day"], name: "index_metrics_on_average_3_day", using: :btree
    t.index ["average_43_hour"], name: "index_metrics_on_average_43_hour", using: :btree
    t.index ["average_4_hour"], name: "index_metrics_on_average_4_hour", using: :btree
    t.index ["average_7_day"], name: "index_metrics_on_average_7_day", using: :btree
    t.index ["average_weighted_10_hour"], name: "index_metrics_on_average_weighted_10_hour", using: :btree
    t.index ["average_weighted_13_hour"], name: "index_metrics_on_average_weighted_13_hour", using: :btree
    t.index ["average_weighted_1_hour"], name: "index_metrics_on_average_weighted_1_hour", using: :btree
    t.index ["average_weighted_21_hour"], name: "index_metrics_on_average_weighted_21_hour", using: :btree
    t.index ["average_weighted_25_hour"], name: "index_metrics_on_average_weighted_25_hour", using: :btree
    t.index ["average_weighted_30_minute"], name: "index_metrics_on_average_weighted_30_minute", using: :btree
    t.index ["average_weighted_43_hour"], name: "index_metrics_on_average_weighted_43_hour", using: :btree
    t.index ["average_weighted_4_hour"], name: "index_metrics_on_average_weighted_4_hour", using: :btree
    t.index ["average_weighted_6_hour"], name: "index_metrics_on_average_weighted_6_hour", using: :btree
    t.index ["bitcoin_price"], name: "index_metrics_on_bitcoin_price", using: :btree
    t.index ["created_at"], name: "index_metrics_on_created_at", using: :btree
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
    t.decimal  "filled_price",        precision: 15, scale: 8
    t.integer  "contract_id"
    t.string   "custom_id"
    t.string   "currency"
    t.decimal  "fees",                precision: 15, scale: 8
    t.string   "status"
    t.string   "type"
    t.datetime "created_at",                                   null: false
    t.datetime "updated_at",                                   null: false
    t.string   "strategy_type"
    t.decimal  "requested_price"
    t.decimal  "executed_value"
    t.index ["contract_id"], name: "index_orders_on_contract_id", using: :btree
    t.index ["executed_value"], name: "index_orders_on_executed_value", using: :btree
    t.index ["fees"], name: "index_orders_on_fees", using: :btree
    t.index ["filled_price"], name: "index_orders_on_filled_price", using: :btree
    t.index ["quantity"], name: "index_orders_on_quantity", using: :btree
    t.index ["requested_price"], name: "index_orders_on_requested_price", using: :btree
    t.index ["status"], name: "index_orders_on_status", using: :btree
    t.index ["strategy_type"], name: "index_orders_on_strategy_type", using: :btree
  end

  create_table "traders", force: :cascade do |t|
    t.string   "name"
    t.text     "description"
    t.boolean  "is_active"
    t.boolean  "is_market_maker"
    t.boolean  "is_trendline"
    t.decimal  "entry_short",      precision: 15, scale: 8
    t.decimal  "entry_long",       precision: 15, scale: 8
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.decimal  "exit_short"
    t.decimal  "exit_long"
    t.decimal  "crossover_buffer"
    t.decimal  "trading_units"
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
