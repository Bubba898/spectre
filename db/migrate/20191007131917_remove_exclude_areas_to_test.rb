class RemoveExcludeAreasToTest < ActiveRecord::Migration[5.0]
  def change
    remove_column :tests, :exclude_areas
  end
end
