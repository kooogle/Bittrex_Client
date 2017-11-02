# t.integer  "chain_id",   limit: 4
# t.float    "last_price", limit: 24
# t.float    "ma5_price",  limit: 24
# t.float    "ma10_price",  limit: 24
# t.date     "mark"
# t.float    "volume",     limit: 24
# t.datetime "created_at",            null: false
# t.datetime "updated_at",            null: false

class Ticker < ActiveRecord::Base
  after_save :sync_ma_price
  self.per_page = 15
  scope :latest, ->{ order(created_at: :desc)}

  def sync_ma_price
    if self.ma5_price.nil?
      self.update_attributes(ma5_price:self.recent_five,ma10_price:self.recent_ten)
    end
  end

  def recent_five
    five_array = Ticker.where('id <= ? and chain_id = ?',self.id,self.chain_id).last(5).map {|x| x.last_price }
    return (five_array.sum / 5).round(8) if five_array.count == 5
    return self.last_price
  end

  def recent_ten
    ten_array = Ticker.where('id <= ? and chain_id = ?',self.id,self.chain_id).last(10).map {|x| x.last_price }
    return (ten_array.sum / 10).round(8) if ten_array.count == 10
    return self.last_price
  end

end
