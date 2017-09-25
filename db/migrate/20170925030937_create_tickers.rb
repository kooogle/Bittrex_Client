class CreateTickers < ActiveRecord::Migration
  def change
    create_table :tickers do |t|
      t.integer :chain_id
      t.float   :last_price
      t.float   :buy_price
      t.float   :sell_price
      t.float   :ma_price
      t.date    :mark
      t.timestamps null: false
    end
  end
end
