# t.integer  "chain_id",   limit: 4
# t.float    "last_price", limit: 24
# t.float    "ma5_price",  limit: 24
# t.float    "ma10_price", limit: 24
# t.date     "mark"
# t.float    "volume",     limit: 24
# t.float    "macd_diff",  limit: 24
# t.float    "macd_dea",  limit: 24
# t.float    "macd_bar",  limit: 24
# t.float    "macd_fast",  limit: 24
# t.float    "macd_slow",  limit: 24
# t.datetime "created_at",  null: false
# t.datetime "updated_at",  null: false

class Ticker < ActiveRecord::Base
  after_save :sync_ma_price
  after_save :sync_macd
  scope :latest, ->{ order(created_at: :desc)}
  self.per_page = 15

  def sync_ma_price
    if self.ma5_price.nil?
      self.update_attributes(ma5_price:self.recent_ema(3),ma10_price:self.recent_ema(8))
    end
  end

  def recent_ema(number)
    ema_array = Ticker.where('id <= ? and chain_id = ?',self.id,self.chain_id).last(number).map {|x| x.last_price }
    average = (ema_array.sum / ema_array.size).round(8)
  end

  def sync_macd
    if self.macd_diff.nil?
      macd_array = self.macd(21,34,8)
      self.update_attributes(macd_fast:macd_array[0],macd_slow:macd_array[1],
        macd_diff:macd_array[2],macd_dea:macd_array[3],macd_bar:macd_array[4])
    end
  end

  def macd(fast,slow,signal)
    pre_block = Ticker.where('id < ? and chain_id = ?',self.id,self.chain_id).last
    if pre_block
      last_price = self.last_price
      ema_fast = pre_block.macd_fast
      ema_slow = pre_block.macd_slow
      ema_dea = pre_block.macd_dea
      fast_val =  last_price * 2 / (fast+1) + ema_fast * (fast - 2) / (fast + 1)
      slow_val =  last_price * 2 / (slow+1) + ema_slow * (slow - 2) / (slow + 1)
      diff_val = fast_val - slow_val
      dea_val =  diff_val * 2 / (signal + 1) + ema_dea *(signal - 2) / (signal + 1)
      bar_val = 2 * (diff_val - dea_val)
    else
      last_price = self.last_price
      fast_val =  last_price * 2 / (fast+1)
      slow_val =  last_price * 2 / (slow+1)
      diff_val = fast_val - slow_val
      dea_val =  diff_val * 2 / (signal + 1)
      bar_val = 2 * (diff_val - dea_val)
    end
    return [fast_val,slow_val,diff_val,dea_val,bar_val]
  end

end
