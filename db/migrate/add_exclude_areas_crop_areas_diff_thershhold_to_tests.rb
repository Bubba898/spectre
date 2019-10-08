class AddEclCropDiffTreshToTEsts < ActiveRecord::Migration
  def change
    add_column :tests, :diff_threshhold, :string
    add_column :tests, :crop_areas, :string
    add_column :tests, :exclude_areas, :string
  end
end