# t.integer  "chain_id",   limit: 4
# t.integer  "deal",       limit: 4
# t.float    "amount",     limit: 24
# t.float    "price",      limit: 24
# t.float    "total",      limit: 24
# t.boolean  "state"
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false

class Order < ActiveRecord::Base
  belongs_to :chain, class_name:'Chain', foreign_key:'chain_id'
  after_save :sync_remote_order, :calculate_total

  def dealing
    {0=>'SELL',1=>'BUY'}[self.deal]
  end

  def stating
    {true=>'已挂单',false=>'未激活'}[self.state]
  end

  def calculate_total
    if self.total.nil?
      self.update_attributes(total: self.amount * self.price)
    end
  end

  def buy?
    return true if self.deal == 1
  end

  def sell?
    return true if self.deal == 0
  end

  def sync_remote_order
    if self.state.nil?
      result = {}
      if self.buy?
        result = self.remote_buy_order rescue {}
      elsif self.sell?
        result = self.remote_sell_order rescue {}
      end
      return self.update_attributes(state:true) if result['success'] == true
      self.update_attributes(state:false)
    end
  end

  def remote_buy_order
    buy_url = 'https://bittrex.com/api/v1.1/market/buylimit'
    res = Faraday.get do |req|
      req.url buy_url
      req.params['apikey'] = Settings.bittrex_key
      req.params['market'] = "#{self.chain.currency}-#{self.chain.block}"
      req.params['quantity'] = self.amount
      req.params['rate'] = self.price
    end
    res = JSON.parse(res.body)
  end

  def remote_sell_order
    sell_url = 'https://bittrex.com/api/v1.1/market/selllimit'
    res = Faraday.get do |req|
      req.url sell_url
      req.params['apikey'] = Settings.bittrex_key
      req.params['market'] = "#{self.chain.currency}-#{self.chain.block}"
      req.params['quantity'] = self.amount
      req.params['rate'] = self.price
    end
    res = JSON.parse(res.body)
  end

end
