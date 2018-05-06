# t.string   "block",      limit: 255
# t.string   "balance",    limit: 24
# t.string   "available",  limit: 24
# t.string   "pending",    limit: 24
# t.string   "address",    limit: 255
# t.datetime "created_at",  null: false
# t.datetime "updated_at",  null: false

class Balance < ActiveRecord::Base

  has_one :chain, class_name:'Chain', primary_key:'block', foreign_key:'block'
  scope :much, -> { order(balance: :asc)}

  def self.sync
    balances = Balance.sync_all rescue []
    balances.each do |item|
      balance = Balance.find_by_block(item['Currency'])
      if item['Balance'] > 0
        balance = Balance.new if balance.nil?
        balance.block = item['Currency']
        balance.balance = item['Balance']
        balance.available = item['Available']
        balance.pending = item['Pending']
        balance.address = item['CryptoAddress']
        balance.save
      elsif balance && item['Balance'] == 0
        balance.destroy
      end
    end
  end

  def self.sync_all
    balances_url = 'https://bittrex.com/api/v1.1/account/getbalances'
    timetamp = Time.now.to_i
    sign_url = "#{balances_url}?apikey=#{Settings.apiKey}&nonce=#{timetamp}"
    res = Faraday.get do |req|
      req.url balances_url
      req.headers['apisign'] = Dashboard.hamc_digest(sign_url)
      req.params['apikey'] = Settings.apiKey
      req.params['nonce'] = timetamp
    end
    result = JSON.parse(res.body)['result']
  end

  def worth
    if self.chain
      self.balance.to_f  * self.chain.market['Bid']
    else
      self.balance.to_f
    end
  end

end
