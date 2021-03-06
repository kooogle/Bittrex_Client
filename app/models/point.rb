# t.integer  "chain_id",     limit: 4
# t.integer  "weights",      limit: 4   权重
# t.float    "low_price",    limit: 24
# t.float    "total_value",  limit: 24
# t.float    "unit",         limit: 24
# t.boolean  "state"
# t.float    "income",       limit: 24
# t.boolean  "frequency",    default: false
# t.float    "high_value",   limit: 24
# t.float    "high_price",   limit: 24
# t.datetime "created_at",   null: false
# t.datetime "updated_at",   null: false

class Point < ActiveRecord::Base
  belongs_to :chain, class_name:'Chain', foreign_key:'chain_id'
  scope :blocked, ->{ order(chain_id: :asc) }
end
