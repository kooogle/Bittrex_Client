# t.integer  "chain_id",   limit: 4
# t.integer  "deal",       limit: 4
# t.float    "amount",     limit: 24
# t.float    "price",      limit: 24
# t.float    "total",      limit: 24
# t.boolean  "state"
# t.string   "result",     limit: 255
# t.boolean  "frequency",  default: false
# t.boolean  "repurchase", default: false
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false

class Order < ActiveRecord::Base
  belongs_to :chain, class_name:'Chain', foreign_key:'chain_id'
  after_create :calculate_total
  after_save :sync_remote_order
  scope :latest, -> { order(created_at: :desc)}

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

  def frequency_cn
    {true=>'高频',false=>'低频'}[self.frequency]
  end

  def repurchase_cn
    {true=>'已出单',false=>'未回购'}[self.repurchase]
  end

  def show_repurchase_cn
    return self.repurchase_cn if self.buy?
  end

  def shown_time
    if Time.now - self.created_at > 1.day
      time_ago_in_words self.created_at
    else
      self.created_at.strftime('%H:%M:%S')
    end
  end

  def calculate_total
    if self.total.nil?
      total = self.amount * self.price * 0.9975
      self.update_attributes(total: total.round(2))
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
      if result['success']
        self.update_attributes(state:true, result:result['result']['uuid'])
        self.sync_repurchase rescue {} if self.sell? #卖出执行回单
        # self.change_point_profit rescue {} unless self.frequency #低频买卖才同步
        return true
      end
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

  def change_point_profit
    if self.buy?
      self.reset_profit
    elsif self.sell?
      self.increase_profit
    end
  end

  def reset_profit
    finance = 0.0618
    fund = self.chain.last_buy_price
    actual = finance * fund
    self.chain.point.update_attributes(income:actual.to_i)
  end

  def increase_profit
    finance = 0.00618
    fund = self.chain.market.first['Bid']
    actual = self.chain.point.income + finance * fund
    self.chain.point.update_attributes(income:actual.to_i)
  end

  def sync_repurchase
    if self.frequency
      self.chain.high_buy_business.first.update_attributes(repurchase:true)
    else
      self.chain.low_buy_business.first.update_attributes(repurchase:true)
    end
  end

end
