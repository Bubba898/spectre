class RemoveExcludeAreasToTest < ActiveRecord::Migration
  def change
    remove_column :tests, :exclude_areas
  end
end