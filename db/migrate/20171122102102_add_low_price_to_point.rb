class AddLowPriceToPoint < ActiveRecord::Migration
  def change
    rename_column :points, :total_amount, :low_price
  end
end
