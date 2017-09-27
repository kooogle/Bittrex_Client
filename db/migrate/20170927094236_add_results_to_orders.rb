class AddResultsToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :result, :string
  end
end
