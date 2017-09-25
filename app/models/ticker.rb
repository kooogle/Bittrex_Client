# t.integer  "chain_id",   limit: 4
# t.float    "last_price", limit: 24
# t.float    "buy_price",  limit: 24
# t.float    "sell_price", limit: 24
# t.float    "ma_price",   limit: 24
# t.date     "mark"
# t.datetime "created_at",            null: false
# t.datetime "updated_at",            null: false

class Ticker < ActiveRecord::Base
  after_save :sync_ma5
  self.per_page = 15
  scope :latest, ->{ order(created_at: :desc)}

  def sync_ma5
    if self.ma_price.nil?
      self.update_attributes(ma_price:self.recent_five)
    end
  end

  def recent_five
    five_array = Ticker.where('id <= ? and chain_id = ?',self.id,self.chain_id).last(5).map {|x| x.last_price }
    return (five_array.sum / 5).round(8) if five_array.count == 5
    return self.last_price
  end

end
