class AddHighBusinessToPoint < ActiveRecord::Migration
  def change
    add_column :points, :frequency, :boolean, default:false
    add_column :points, :high_value, :float
    add_column :points, :high_price, :float
  end
end
