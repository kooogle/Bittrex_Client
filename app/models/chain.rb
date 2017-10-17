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

  def full_name
    "#{self.currency}-#{self.block}"
  end

  def quote
    ticker_url = 'https://bittrex.com/api/v1.1/public/getticker'
    res = Faraday.get do |req|
      req.url ticker_url
      req.params['market'] = "#{self.currency}-#{self.block}"
    end
    current = JSON.parse(res.body)
    current['result']
  end

  def market
    market_url = 'https://bittrex.com/api/v1.1/public/getmarketsummary'
    res = Faraday.get do |req|
      req.url market_url
      req.params['market'] = "#{self.currency}-#{self.block}"
    end
    current = JSON.parse(res.body)
    current['result']
  end

  def generate_ticker
    quote = self.quote
    ticker = Ticker.new
    ticker.chain_id = self.id
    ticker.last_price = quote['Last']
    ticker.buy_price = quote['Bid']
    ticker.sell_price = quote['Ask']
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
    result = JSON.parse(res.body)['reslut']
  end

  def high
    self.tickers.last(48).map {|x| x.last_price}.max
  end

  def low
    self.tickers.last(48).map {|x| x.last_price}.min
  end

  def high_nearby(price)
    return true if self.high * 0.99618 < price && self.high * 1.00382 > price
  end

  def low_nearby(price)
    return true if self.low * 0.99618 < price && self.low * 1.00382 > price
  end


end
