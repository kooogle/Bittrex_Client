class AddIncomeToPoints < ActiveRecord::Migration
  def change
    add_column :points, :income, :float
  end
end
