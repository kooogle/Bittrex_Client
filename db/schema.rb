# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20170927094236) do

  create_table "balances", force: :cascade do |t|
    t.string   "block",      limit: 255
    t.float    "balance",    limit: 24
    t.float    "available",  limit: 24
    t.float    "pending",    limit: 24
    t.string   "address",    limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "chains", force: :cascade do |t|
    t.string   "block",      limit: 255
    t.string   "currency",   limit: 255
    t.string   "label",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer  "chain_id",   limit: 4
    t.integer  "deal",       limit: 4
    t.float    "amount",     limit: 24
    t.float    "price",      limit: 24
    t.float    "total",      limit: 24
    t.boolean  "state"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.string   "result",     limit: 255
  end

  create_table "points", force: :cascade do |t|
    t.integer  "chain_id",     limit: 4
    t.integer  "weights",      limit: 4
    t.float    "total_amount", limit: 24
    t.float    "total_value",  limit: 24
    t.float    "unit",         limit: 24
    t.boolean  "state"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
  end

  create_table "tickers", force: :cascade do |t|
    t.integer  "chain_id",   limit: 4
    t.float    "last_price", limit: 24
    t.float    "buy_price",  limit: 24
    t.float    "sell_price", limit: 24
    t.float    "ma_price",   limit: 24
    t.date     "mark"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "email",                  limit: 255, default: "", null: false
    t.string   "encrypted_password",     limit: 255, default: "", null: false
    t.string   "reset_password_token",   limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",          limit: 4,   default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",     limit: 255
    t.string   "last_sign_in_ip",        limit: 255
    t.integer  "role",                   limit: 4,   default: 1
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "users", ["email"], name: "index_users_on_email", unique: true, using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree

end
