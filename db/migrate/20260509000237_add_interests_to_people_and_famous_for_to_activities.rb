class AddInterestsToPeopleAndFamousForToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :interests, :string, array: true, null: false, default: []
    add_column :activities, :famous_for, :text
    add_column :trips, :excitement_pitch, :text
  end
end
