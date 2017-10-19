class Api::QuotesController < ApplicationController
  #每30分钟获取一直价格，生成历史行情
  def hit_tickers
    Chain.all.each do |item|
      item.generate_ticker rescue nil
    end
    render json:{code:200}
  end
  #每10分钟获取一次最新价格，根据价格涨幅做买卖通知
  def hit_market
    Chain.all.each do |item|
      # quote_analysis(item) rescue nil
      quote_report(item) rescue nil
    end
    render json:{code:200}
  end

private

  def amplitude(old_price,new_price)
    return ((new_price - old_price) / old_price * 100).to_i
  end

  def quote_report(market)
    market = block.market
    if block.high_nearby(market['Bid'])
      string = "#{self.currency}-#{self.block} 接近最高价，买一价：#{market['Bid']}"
    elsif block.low_nearby(market['Ask'])
      string = "#{self.currency}-#{self.block} 接近最低价，买一价：#{market['Ask']}"
    end
    User.sms_yunpian(string)
  end

  def quote_analysis(block)
    market = block.market
    ma5_price = block.tickers.last.ma5_price
    ma10_price = block.tickers.last.ma10_price
    if ma5_price > ma10_price
      sell_analysis(block,market)
    elsif ma5_price < ma10_price
      buy_analysis(block,market)
    end
  end

  def buy_analysis(block,market)
    last_price = market['Ask']
  end

  def sell_analysis(block,market)
    last_price = market['Bid']
    quote12 = block.tickers.last(12).map {|x| x.last_price }
  end

end