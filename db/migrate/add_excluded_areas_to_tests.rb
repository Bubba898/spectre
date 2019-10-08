class AddExcludeedAreasToTests < ActiveRecord::Migration
  def change
    add_column :tests, :excluded_areas, :string
  end
end