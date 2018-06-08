class ChangeWeightTypeToPoints < ActiveRecord::Migration
  def change
    change_column :points, :weights, :float
  end
end
