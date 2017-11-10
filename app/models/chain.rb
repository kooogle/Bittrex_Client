# t.string   "block",      limit: 255
# t.string   "currency",   limit: 255
# t.string   "label",      limit: 255
# t.datetime "created_at", null: false
# t.datetime "updated_at", null: false

class Chain < ActiveRecord::Base
  scope :named, ->{ order(block: :asc)}
  validates_presence_of :block, :currency, :label
  validates_uniqueness_of :block, scope: :currency
  self.per_page = 10
  has_many :tickers, dependent: :destroy
  has_many :business, class_name:'Order'
  has_one :point, class_name:'Point'
  has_one :wallet, class_name:'Balance', primary_key:'block', foreign_key:'block'

  def full_name
    "#{self.block}-#{self.currency}"
  end

  def to_cny
    # finance_url = 'https://finance.yahoo.com/webservice/v1/symbols/allcurrencies/quote?format=json'
    # res = Faraday.get(finance_url)
    # finances = JSON.parse(res.body)
    # finances['list']['resources'].each do |item|
    #   if item['resource']['fields']['name'] == 'USD/CNY'
    #     cny_finance = item['resource']['fields']['price'].to_f
    #   end
    # end
    cny_finance = 6.6375
    return (cny_finance * self.quote["Last"]).round(2) if self.currency == 'USDT'
    return (cny_finance * Chain.where(block:'ETH',currency:'USDT').first.quote["Last"]).round(2) if self.currency == 'ETH'
    return (cny_finance * Chain.where(block:'BTC',currency:'USDT').first.quote["Last"]).round(2) if self.currency == 'BTC'
    cny_finance
  end

  def markets
    "#{self.currency}-#{self.block}"
  end

  def quote
    ticker_url = 'https://bittrex.com/api/v1.1/public/getticker'
    res = Faraday.get do |req|
      req.url ticker_url
      req.params['market'] = self.markets
    end
    current = JSON.parse(res.body)
    current['result']
  end

  def market
    market_url = 'https://bittrex.com/api/v1.1/public/getmarketsummary'
    res = Faraday.get do |req|
      req.url market_url
      req.params['market'] = self.markets
    end
    current = JSON.parse(res.body)
    current['result']
  end

  def generate_ticker
    quote = self.market.first
    ticker = Ticker.new
    ticker.chain_id = self.id
    ticker.last_price = quote['Last']
    ticker.volume = quote['Volume']
    ticker.mark = Date.current.to_s
    ticker.save
  end

  def balance
    balance_url = 'https://bittrex.com/api/v1.1/account/getbalance'
    timetamp = Time.now.to_i
    sign_url = "#{balance_url}?apikey=#{Settings.apiKey}&currency=#{self.block}&nonce=#{timetamp}"
    res = Faraday.get do |req|
      req.url balance_url
      req.headers['apisign'] = Dashboard.hamc_digest(sign_url)
      req.params['apikey'] = Settings.apiKey
      req.params['currency'] = self.block
      req.params['nonce'] = timetamp
    end
    result = JSON.parse(res.body)
    result['result']['Available']
  end

  def money
    balances = Balance.sync_all
    balances.each do |balance|
      if balance['Currency'] == self.currency.to_s
        return balance['Available']
      end
    end
  end

  def greater_income
    self.last_buy_price + self.point.income
  end

  def last_buy_price
    if buy = self.business.where(deal:1,state:true).last(5)
      buy_array = buy.map {|x| x.price }
      buy_average = buy_array.sum / buy_array.size
      return buy_average.to_i if buy_average.to_i > 0
      return buy_average.round(6)
    end
    0
  end

  def high
    self.tickers.last(48).map {|x| x.last_price}.max
  end

  def low
    self.tickers.last(48).map {|x| x.last_price}.min
  end

  def high_nearby(price)
    return true if self.high * 0.99382 < price && self.high > price
    false
  end

  def low_nearby(price)
    return true if self.low < price && self.low * 1.00618 > price
    false
  end

  def ma_up_down_point?
    ma_gap = self.tickers.last(5).map {|x| (x.ma5_price - x.ma10_price).round(8)}
    return true if ma_gap.min > 0 && ma_gap.max == ma_gap[-2]
    false
  end

  def ma_down_up_point?
    ma_gap = self.tickers.last(5).map {|x| (x.ma5_price - x.ma10_price).round(8)}
    return true if ma_gap.max < 0 && ma_gap.min == ma_gap[-2]
    false
  end

  def kling_up_down_point?
    ling = self.tickers.last(24).map {|x| x.last_price}
    return true if ling.max == [-2]
    false
  end

  def kling_down_up_point?
    ling = self.tickers.last(24).map {|x| x.last_price}
    return true if ling.min == [-2]
    false
  end

  def market_rise?
    last_1_day_max = self.tickers.where(mark:(Date.current - 1.day).to_s).map {|x| x.last_price}.max
    last_2_day_max = self.tickers.where(mark:(Date.current - 2.day).to_s).map {|x| x.last_price}.max
    return true if last_1_day_max > last_2_day_max
    false
  end

  def market_fall?
    last_1_day_min = self.tickers.where(mark:(Date.current - 1.day).to_s).map {|x| x.last_price}.min
    last_2_day_min = self.tickers.where(mark:(Date.current - 2.day).to_s).map {|x| x.last_price}.min
    return true if last_2_day_min > last_1_day_min
    false
  end

  def available_money
    max_buy = self.point.total_value
    money = self.money
    return max_buy if money > max_buy
    money
  end


end
