class AddPlanningPreferencesToTrips < ActiveRecord::Migration[8.1]
  def change
    change_table :trips, bulk: true do |t|
      t.string :pace        # relaxed | balanced | packed — shapes activities/day + downtime
      t.string :budget      # shoestring | moderate | comfortable | luxury — lodging/dining/attraction tier
      t.text   :preferences # free-form: dietary, accessibility/mobility, must-dos, things to avoid
    end
  end
end
