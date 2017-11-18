class AddMacdToTickers < ActiveRecord::Migration
  def change
  	add_column :tickers, :macd_fast, :float
  	add_column :tickers, :macd_slow, :float
  	add_column :tickers, :macd_diff, :float
  	add_column :tickers, :macd_dea, :float
  	add_column :tickers, :macd_bar, :float
  end
end
