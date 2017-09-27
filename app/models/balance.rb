# t.string   "block",      limit: 255
# t.float    "balance",    limit: 24
# t.float    "available",  limit: 24
# t.float    "pending",    limit: 24
# t.string   "address",    limit: 255
# t.datetime "created_at",  null: false
# t.datetime "updated_at",  null: false

class Balance < ActiveRecord::Base

  def self.sync
    balances = Balance.sync_all rescue []
    balances.each do |item|
      if item['Balance'] > 0
        Balance.find_or_create_by(block:item['Currency']) do |balance|
          balance.balance = item['Balance']
          balance.available = item['Available']
          balance.pending = item['Pending']
          balance.address = item['CryptoAddress']
        end
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

end
