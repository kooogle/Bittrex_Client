class Blocks::DashboardController < Blocks::BaseController

  def index
    block = params[:block] || Chain.first.id
    sta_time = params[:start] || Date.current.to_s
    end_time = params[:end] || Date.current.to_s
    @block = Chain.find(block)
    tickers = @block.tickers.where("mark >= ? AND mark <= ?",sta_time,end_time)
    tickers = @block.tickers.last(24) if tickers.count < 10
    @date_array = tickers.map {|x| x.created_at.strftime('%m-%d %H:%M')}
    @value_array = tickers.map {|x| x.last_price}
    @ma5_array = tickers.map {|x| x.ma5_price}
    @ma10_array = tickers.map {|x| x.ma10_price}
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
