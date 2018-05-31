class Blocks::DashboardController < Blocks::BaseController

  def index
    block = params[:block] || Chain.first.id
    sta_time = params[:start] || Date.current.to_s
    end_time = params[:end] || Date.current.to_s
    @block = Chain.find(block)
    tickers = @block.tickers.where("mark >= ? AND mark <= ?",sta_time,end_time)
    tickers = @block.tickers.where("id <= ?", tickers.last.id).last(96) if tickers.count < 96 && tickers.count > 0
    tickers = @block.tickers.last(96) if tickers.count == 0
    @price_array = tickers.map {|x| [x.created_at.to_i * 1000,x.last_price] }
    @date_data = tickers.map {|x| x.created_at.to_i * 1000 }
    @macd_diff = tickers.map {|x| x.macd_diff}
    @macd_dea = tickers.map {|x| x.macd_dea}
    @macd_bar = tickers.map {|x| x.macd_bar / 2}
  end

  def index_old
    block = params[:block] || Chain.first.id
    sta_time = params[:start] || Date.current.to_s
    end_time = params[:end] || Date.current.to_s
    @block = Chain.find(block)
    tickers = @block.tickers.where("mark >= ? AND mark <= ?",sta_time,end_time)
    tickers = @block.tickers.where("id <= ?", tickers.last.id).last(96) if tickers.count < 96 && tickers.count > 0
    tickers = @block.tickers.last(96) if tickers.count == 0
    @date_array = tickers.map {|x| x.created_at.strftime('%d %H:%M')}
    @last_price = tickers.map {|x| x.last_price }
    @macd_diff = tickers.map {|x| x.macd_diff}
    @macd_dea = tickers.map {|x| x.macd_dea}
    @ma_diff = tickers.map {|x| x.ma5_price - x.ma10_price}
  end

  def pending
    currency = ['BTC','ETH','USDT']
    @orders = []
    Balance.all.each do |item|
      block = item.block
      currency.each do |curr|
        if block != curr && item.balance.to_f > 0
          market = "#{curr}-#{block}"
          order = Order.pending(market)
          order['result'].map {|item_order| @orders << item_order } if order['result'].present?
        end
      end
    end
    @orders
  end

end
