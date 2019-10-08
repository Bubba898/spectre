class AddExcludedAreasToTests < ActiveRecord::Migration[5.0]
  def change
    add_column :tests, :excluded_areas, :string
  end
end
