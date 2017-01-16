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

ActiveRecord::Schema.define(version: 20170116203204) do

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
