class Api::TradingViewsController < ApplicationController

  def trading_config
    config_hash = {}
    config_hash[:supports_search] = true
    config_hash[:supports_group_request] = false
    config_hash[:supported_resolutions] = ["15", "30", "60", "360","720","1440"]
    config_hash[:supports_marks] = false
    config_hash[:supports_time] = true
    render json: config_hash
  end

  def symbols
    config_hash = {}
    config_hash[:name] = params[:symbol]
    config_hash[:ticker] = params[:symbol]
    config_hash[:description] = params[:symbol].upcase
    config_hash[:timezone] = 'Asia/Shanghai'
    config_hash[:pricescale] = 10 ** 5
    config_hash[:session] = '24x7'
    config_hash[:minmov] = 1
    config_hash[:data_status] = 'streaming'
    config_hash[:supported_resolutions] = ["15", "30", "60", "360","720","1440"]
    config_hash[:has_intraday] = true
    config_hash[:intraday_multipliers] = [15]
    config_hash[:has_daily] = true
    config_hash[:has_weekly_and_monthly] = true
    render json: config_hash
  end

  def history
    markets = Chain.market_list
    from_time = Time.at params[:from].to_i
    to_time = Time.at params[:to].to_i
    tickers = Ticker.where(chain_id: markets[params[:symbol]]).where("created_at >= ? and created_at < ?",from_time,to_time)
    markets_body = {}
    tickers.each_with_index do |ticker,index|
      markets_body[:t] << ticker.created_at.to_i rescue      markets_body[:t] = [ticker.created_at.to_i]
      markets_body[:o] << ticker.last_price rescue           markets_body[:o] = [ticker.last_price]
      markets_body[:h] << ticker.last_price * 1.0025 rescue    markets_body[:h] = [ticker.last_price * 1.25]
      markets_body[:l] << ticker.last_price * 0.9975 rescue    markets_body[:l] = [ticker.last_price * 0.75]
      markets_body[:c] << tickers[index + 1].try(:last_price) || ticker.last_price rescue markets_body[:c] = [tickers[index + 1].last_price]
      markets_body[:v] << (rand * 10000).to_i rescue         markets_body[:v] = [(rand * 10000).to_i]
    end
    markets_body[:t] ? markets_body[:s] = 'ok' : markets_body[:s] = 'no_data'
    render json: markets_body
  end

  def time
    render text: Time.now.to_i
  end

end