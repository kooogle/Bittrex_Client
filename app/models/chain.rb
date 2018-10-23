# t.string   "block",      limit: 255
# t.string   "currency",   limit: 255
# t.string   "label",      limit: 255
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false

class Chain < ActiveRecord::Base
  scope :named, ->{ order(block: :asc) }
  validates_presence_of :block, :currency, :label
  validates_uniqueness_of :block, scope: :currency
  self.per_page = 10
  has_many :tickers, dependent: :destroy
  has_many :business, class_name:'Order'
  has_many :buy_business,->{where(deal:1,state:true,repurchase:false)}, class_name:'Order' #所有买单记录
  has_many :low_buy_business,->{where(deal:1,state:true,frequency:false,repurchase:false)}, class_name:'Order' #低频买单记录
  has_many :high_buy_business,->{where(deal:1,state:true,frequency:true,repurchase:false)}, class_name:'Order' #高频买单价格未回购记录
  has_one :point, class_name:'Point'
  has_one :wallet, class_name:'Balance', primary_key:'block', foreign_key:'block'


  def self.amplitude(old_price,new_price)
    return ((new_price - old_price) / old_price.to_f * 100).round(2)
  end

  def last_price
    tickers.last.last_price
  end

  def market_price
    market["Last"] || last_price
  end

  def available_amount
    wallet.try(:balance) || 0
  end

  def full_name
    "#{block}-#{currency}"
  end

  def point_state
    point.try(:state)
  end

  def buy_cost
    cost = buy_business.map {|x| x.total }.sum
    return cost.round(2) if cost > 0
    '一'
  end

  def prev_day_price
    last_day = tickers.where(mark:Date.current.yesterday).map(&:last_price)
    if last_day.any?
      (last_day.max + last_day.min) / 2.0
    else
      return nil
    end
  end

  def buy_price
    buy_business = buy_business
    if buy_business.count > 0
      price = buy_business.map {|x| x.total }.sum / buy_business.map {|x| x.amount }.sum
      return price.round(2)
    end
    '一'
  end

  #获取实时的人民币/美元汇率
  # finance_url = 'https://finance.yahoo.com/webservice/v1/symbols/allcurrencies/quote?format=json'
  # res = Faraday.get(finance_url)
  # finances = JSON.parse(res.body)
  # finances['list']['resources'].each do |item|
  #   if item['resource']['fields']['name'] == 'USD/CNY'
  #     cny_finance = item['resource']['fields']['price'].to_f
  #   end
  # end

  def to_cny
    cny_finance = 6.6375
    return (cny_finance * quote["Last"]).round(2) if currency == 'USDT'
    return (cny_finance * Chain.where(block:'ETH',currency:'USDT').first.quote["Last"]).round(2) if currency == 'ETH'
    return (cny_finance * Chain.where(block:'BTC',currency:'USDT').first.quote["Last"]).round(2) if currency == 'BTC'
    cny_finance
  end

  def to_usdt
    if currency == 'USDT'
      return (market["Last"])
    elsif currency == 'ETH'
      return ((Chain.where(block:'ETH',currency:'USDT').first.market["Last"]) * last_price)
    elsif currency == 'BTC'
      return ((Chain.where(block:'BTC',currency:'USDT').first.market["Last"]) * last_price)
    end
  end

  def markets
    "#{currency}-#{block}"
  end

  def quote
    ticker_url = 'https://bittrex.com/api/v1.1/public/getticker'
    res = Faraday.get do |req|
      req.url ticker_url
      req.params['market'] = markets
    end
    current = JSON.parse(res.body)
    current['result']
  end

  def market
    market_url = 'https://bittrex.com/api/v1.1/public/getmarketsummary'
    res = Faraday.get do |req|
      req.url market_url
      req.params['market'] = markets
    end
    current = JSON.parse(res.body)
    current['result'][0]
  end

  def generate_ticker
    quote = market
    ticker = Ticker.new
    ticker.chain_id = id
    ticker.last_price = quote['Last']
    ticker.volume = quote['Volume']
    ticker.mark = Date.current.to_s
    ticker.save
  end

  def balance
    balance_url = 'https://bittrex.com/api/v1.1/account/getbalance'
    timetamp = Time.now.to_i
    sign_url = "#{balance_url}?apikey=#{Settings.apiKey}&currency=#{block}&nonce=#{timetamp}"
    res = Faraday.get do |req|
      req.url balance_url
      req.headers['apisign'] = Dashboard.hamc_digest(sign_url)
      req.params['apikey'] = Settings.apiKey
      req.params['currency'] = block
      req.params['nonce'] = timetamp
    end
    result = JSON.parse(res.body)
    availiable = result['result']['Available']
    clear_buy_order if availiable == 0 || availiable.nil?
    availiable
  end

  def clear_buy_order
    business.where(repurchase:false,deal:1).destroy_all
  end

  def money
    balances = Balance.sync_all
    balances.each do |balance|
      if balance['Currency'] == currency.to_s
        return balance['Available']
      end
    end
  end

  def greater_income
    last_buy_price + point.income
  end

  def income
    point.income
  end

  def last_buy_price
    if buy = low_buy_business.last(5)
      buy_array = buy.map {|x| x.price }
      buy_average = buy_array.sum / buy_array.size
      return buy_average.to_i if buy_average.to_i > 0
      return buy_average.round(6)
    end
    0
  end

  def high
    tickers.last(96).map {|x| x.last_price}.max
  end

  def low
    tickers.last(96).map {|x| x.last_price}.min
  end

  def high_nearby(price)
    return true if high * 0.99382 < price && high > price
    false
  end

  def low_nearby(price)
    return true if low < price && low * 1.00618 > price
    false
  end

  def ma_up_down_point?
    ma_gap = tickers.last(5).map {|x| (x.ma5_price - x.ma10_price).round(8)}
    return true if ma_gap.min > 0 && ma_gap.max == ma_gap[-2]
    false
  end

  def ma_down_up_point?
    ma_gap = tickers.last(5).map {|x| (x.ma5_price - x.ma10_price).round(8)}
    return true if ma_gap.max < 0 && ma_gap.min == ma_gap[-2]
    false
  end

  def kling_up_down_point?
    ling = tickers.last(24).map {|x| x.last_price}
    return true if ling.max == [-2]
    false
  end

  def kling_down_up_point?
    ling = tickers.last(24).map {|x| x.last_price}
    return true if ling.min == [-2]
    false
  end

  def market_rise?
    last_1_day_max = tickers.where(mark:(Date.current - 1.day).to_s).map {|x| x.last_price}.max
    last_2_day_max = tickers.where(mark:(Date.current - 2.day).to_s).map {|x| x.last_price}.max
    return true if last_1_day_max > last_2_day_max
    false
  end

  def market_fall?
    last_1_day_min = tickers.where(mark:(Date.current - 1.day).to_s).map {|x| x.last_price}.min
    last_2_day_min = tickers.where(mark:(Date.current - 2.day).to_s).map {|x| x.last_price}.min
    return true if last_2_day_min > last_1_day_min
    false
  end

  def close_merch
    point.update_attributes(state:false)
  end

  def open_merch
    point.update_attributes(state:true)
  end

  def bull_market_tip(magnitude,ticker)
    title = "#{block} 牛市归来"
    content = "涨幅 #{magnitude}口价格 #{ticker['Last']}口时间 #{Time.now.strftime('%H:%M')}"
    sms_content = "#{full_name}; 上涨：⬆️ #{magnitude}、价格: #{tickers.last.last_price} #{currency} 时间：#{Time.now.strftime('%H:%M')}"
    User.wechat_group_notice(title,content)
    User.sms_notice(sms_content) if point.try(:state)
  end

  def bear_market_tip(magintude,ticker)
    title = "#{block} 熊市来袭"
    content = "跌幅 -#{magintude}口价格 #{ticker['Last']}口时间 #{Time.now.strftime('%H:%M')}"
    sms_content = "#{full_name}; 下跌：⬇️ #{magnitude}、价格: #{tickers.last.last_price} #{currency} 时间：#{Time.now.strftime('%H:%M')}"
    User.wechat_group_notice(title,content)
    User.sms_notice(sms_content) if point.try(:state)
  end

  def kelly_profit

  end

  def self.market_list
    market_hash = {}
    Chain.all.order(block: :asc).map {|x| market_hash[x.markets] = x.id }
    market_hash
  end

end
