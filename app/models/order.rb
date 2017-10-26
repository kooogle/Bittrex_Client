# t.integer  "chain_id",   limit: 4
# t.integer  "deal",       limit: 4
# t.float    "amount",     limit: 24
# t.float    "price",      limit: 24
# t.float    "total",      limit: 24
# t.boolean  "state"
# t.string   "result",     limit: 255
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false

class Order < ActiveRecord::Base
  belongs_to :chain, class_name:'Chain', foreign_key:'chain_id'
  after_create :calculate_total
  after_save :sync_remote_order

  self.per_page = 10

  def self.total_buy
    Order.where(deal:1).where(state:true).map {|x| x.total}.sum.round(2)
  end

  def self.total_sell
    Order.where(deal:0).where(state:true).map {|x| x.total}.sum.round(2)
  end

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
      return self.update_attributes(state:true, result:result['result']['uuid']) if result['success']
      self.update_attributes(state:false, result:result['message'])
    end
  end

  def remote_buy_order
    buy_url = 'https://bittrex.com/api/v1.1/market/buylimit'
    self.remote_order(buy_url)
  end

  def remote_sell_order
    sell_url = 'https://bittrex.com/api/v1.1/market/selllimit'
    self.remote_order(sell_url)
  end

  def sign_query(timetamp)
    query_arry = ["apikey=#{Settings.apiKey}","market=#{self.chain.markets}","nonce=#{timetamp}","quantity=#{self.amount}","rate=#{self.price}"]
    query_arry.sort.join('&')
  end

  def remote_order(deal_url)
    timetamp = Time.now.to_i
    sign_url = "#{deal_url}?#{self.sign_query(timetamp)}"
    res = Faraday.get do |req|
      req.url deal_url
      req.headers['apisign'] = Dashboard.hamc_digest(sign_url)
      req.params['apikey'] = Settings.apiKey
      req.params['market'] = self.chain.markets
      req.params['nonce'] = timetamp
      req.params['quantity'] = self.amount
      req.params['rate'] = self.price
    end
    result = JSON.parse(res.body)
  end

  def self.pending(market)
    timetamp = Time.now.to_i
    open_order_url = 'https://bittrex.com/api/v1.1/market/getopenorders'
    sign_url = "#{open_order_url}?apikey=#{Settings.apiKey}&market=#{market}&nonce=#{timetamp}"
    res = Faraday.get do |req|
      req.url open_order_url
      req.headers['apisign'] = Dashboard.hamc_digest(sign_url)
      req.params['apikey'] = Settings.apiKey
      req.params['market'] = market
      req.params['nonce'] = timetamp
    end
    result = JSON.parse(res.body)
  end

  def self.cancel(uuid)
    timetamp = Time.now.to_i
    cancel_order_url = 'https://bittrex.com/api/v1.1/market/cancel'
    sign_url = "#{cancel_order_url}?apikey=#{Settings.apiKey}&nonce=#{timetamp}&uuid=#{uuid}"
    res = Faraday.get do |req|
      req.url cancel_order_url
      req.headers['apisign'] = Dashboard.hamc_digest(sign_url)
      req.params['apikey'] = Settings.apiKey
      req.params['uuid'] = uuid
      req.params['nonce'] = timetamp
    end
    result = JSON.parse(res.body)
  end

end
