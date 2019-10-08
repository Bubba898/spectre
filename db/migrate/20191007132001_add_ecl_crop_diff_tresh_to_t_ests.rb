class AddEclCropDiffTreshToTEsts < ActiveRecord::Migration[5.0]
  def change
    add_column :tests, :diff_threshhold, :string
    add_column :tests, :crop_areas, :string
  end
end
