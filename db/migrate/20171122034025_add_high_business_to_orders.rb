class AddHighBusinessToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :frequency, :boolean, default:false
    add_column :orders, :repurchase, :boolean, default:false
  end
end
