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
    {0=>'SELL',1=>'BUY'}[deal]
  end

  def stating
    {true=>'已下单',false=>'未激活'}[state]
  end

  def frequency_cn
    {true=>'高频',false=>'低频'}[frequency]
  end

  def repurchase_cn
    {true=>'已出单',false=>'未回购'}[repurchase]
  end

  def show_repurchase_cn
    return repurchase_cn if buy?
  end

  def shown_time
    if Time.now - created_at > 1.day
      time_ago_in_words created_at
    else
      created_at.strftime('%H:%M:%S')
    end
  end

  def calculate_total
    if total.nil?
      total = amount * price
      update_attributes(total: total.round(2))
    end
  end

  def buy?
    return true if deal == 1
  end

  def sell?
    return true if deal == 0
  end

  def sync_remote_order
    if state.nil?
      result = {}
      if buy?
        result = remote_buy_order rescue {}
      elsif sell?
        result = remote_sell_order rescue {}
      end
      if result['success']
        update_attributes(state:true, result:result['result']['uuid'])
        # sync_repurchase rescue {} if sell? #卖出执行回单
        # change_point_profit rescue {} unless frequency #低频买卖才同步
        return true
      end
      update_attributes(state:false, result:result['message'])
    end
  end

  def remote_buy_order
    buy_url = 'https://bittrex.com/api/v1.1/market/buylimit'
    remote_order(buy_url)
  end

  def remote_sell_order
    sell_url = 'https://bittrex.com/api/v1.1/market/selllimit'
    remote_order(sell_url)
  end

  def sign_query(timetamp)
    query_arry = ["apikey=#{Settings.apiKey}","market=#{chain.markets}","nonce=#{timetamp}","quantity=#{amount}","rate=#{price}"]
    query_arry.sort.join('&')
  end

  def remote_order(deal_url)
    timetamp = Time.now.to_i
    sign_url = "#{deal_url}?#{sign_query(timetamp)}"
    res = Faraday.get do |req|
      req.url deal_url
      req.headers['apisign'] = Dashboard.hamc_digest(sign_url)
      req.params['apikey'] = Settings.apiKey
      req.params['market'] = chain.markets
      req.params['nonce'] = timetamp
      req.params['quantity'] = amount
      req.params['rate'] = price
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
    if buy?
      reset_profit
    elsif sell?
      increase_profit
    end
  end

  def reset_profit
    finance = 0.0618
    fund = chain.last_buy_price
    actual = finance * fund
    chain.point.update_attributes(income:actual.to_i)
  end

  def increase_profit
    finance = 0.00618
    fund = chain.market['Bid']
    actual = chain.point.income + finance * fund
    chain.point.update_attributes(income:actual.to_i)
  end

  #交易完成后同步订单的
  def sync_repurchase
    if frequency
      chain.high_buy_business.order(price: :asc).first.update_attributes(repurchase:true)
    else
      chain.low_buy_business.first.update_attributes(repurchase:true)
    end
  end

end
