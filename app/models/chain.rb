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
    yzmb_url = 'https://bittrex.com/api/v1.1/public/getticker'
    res = Faraday.get do |req|
      req.url yzmb_url
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

end
