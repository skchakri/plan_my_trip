class AddGuideScriptToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :guide_script, :text
  end
end
