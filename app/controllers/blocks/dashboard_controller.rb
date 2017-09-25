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
    @ma5_array = tickers.map {|x| x.ma_price}
  end

end
